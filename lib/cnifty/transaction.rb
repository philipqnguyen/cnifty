require 'tempfile'
require 'securerandom'

module Cnifty
  class Transaction
    attr_reader :ada,
                :payment_address,
                :destination_address,
                :change_address,
                :token,
                :era,
                :chain,
                :protocol

    def initialize(ada:,
                   payment_address:,
                   destination_address:,
                   change_address: nil,
                   token: nil)
      @ada = ada.to_i
      @payment_address = payment_address
      @destination_address = destination_address
      @change_address = change_address || payment_address
      @token = token
      @chain = 'testnet-magic 1097911063'
      @era = 'alonzo-era'
      @protocol = Protocol.new
    end

    def submit
      write_payment_address_skey_file
      write_protocol_file
      execute_raw_transaction_command
      fee = execute_calculate_min_fee_command
      execute_raw_transaction_with_fees_command(fee)
      execute_sign_raw_transaction_command
      execute_submit_command
      execute_read_transaction_id
    rescue CardanoNodeError
      false
    ensure
      transaction_file_raw.close
      transaction_file_raw.unlink
      transaction_file_signed.close
      transaction_file_signed.unlink
      payment_address_skey_file.close
      payment_address_skey_file.unlink
    end

  private

    def seed
      @seed ||= SecureRandom.uuid
    end

    def transaction_file_raw
      @transaction_file_raw ||= Tempfile.new "transaction_#{seed}.raw"
    end

    def transaction_file_signed
      @transaction_file_signed ||= Tempfile.new "transaction_#{seed}.signed"
    end

    def payment_address_skey_file
      @payment_address_skey_file ||= Tempfile.new "payment_#{seed}.skey"
    end

    def protocol_file
      @protocol_file ||= Tempfile.new "protocol_#{seed}.json"
    end

    def write_protocol_file
      File.write protocol_file, protocol.to_s
    end

    def write_payment_address_skey_file
      File.write payment_address_skey_file, payment_address.skey
    end

    def execute_raw_transaction_command
      cmd = """
      cardano-cli transaction build-raw \
        --invalid-hereafter #{slot} \
        --#{era} \
        --fee 0 \
        #{tx_ins_str} \
        --tx-out #{tx_out} \
        --tx-out #{change_tx_out(fee: 0)} \
        --out-file #{transaction_file_raw.path}
      """
      stdout, stderr, status = Open3.capture3(cmd.strip)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus !=0
      true
    end

    def execute_calculate_min_fee_command
      cmd = """
      cardano-cli transaction calculate-min-fee \
        --tx-body-file #{transaction_file_raw.path} \
        --tx-in-count #{tx_ins.count} \
        --tx-out-count 2 \
        --witness-count 1 \
        --#{chain} \
        --protocol-params-file #{protocol_file.path}
      """
      stdout, stderr, status = Open3.capture3(cmd.strip)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus !=0
      stdout.strip.split(' ').first
    end

    def execute_raw_transaction_with_fees_command(fee)
      cmd = """
      cardano-cli transaction build-raw \
        --invalid-hereafter #{slot} \
        --#{era} \
        --fee #{fee} \
        #{tx_ins_str} \
        --tx-out #{tx_out} \
        --tx-out #{change_tx_out(fee: fee)} \
        --out-file #{transaction_file_raw.path}
      """
      stdout, stderr, status = Open3.capture3(cmd.strip)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus !=0
      true
    end

    def execute_sign_raw_transaction_command
      cmd = """
      cardano-cli transaction sign \
        --signing-key-file #{payment_address_skey_file.path} \
        --#{chain} \
        --tx-body-file #{transaction_file_raw.path} \
        --out-file #{transaction_file_signed.path}
      """
      stdout, stderr, status = Open3.capture3(cmd.strip)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus != 0
      true
    end

    def execute_submit_command
      cmd = """
      cardano-cli transaction submit \
        --tx-file #{transaction_file_signed.path} \
        --#{chain}
      """
      stdout, stderr, status = Open3.capture3(cmd.strip)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus != 0
      true
    end

    def execute_read_transaction_id
      cmd = """
      cardano-cli transaction txid --tx-file #{transaction_file_signed.path}
      """
      stdout, stderr, status = Open3.capture3(cmd.strip)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus != 0
      stdout
    end

    def slot
      @slot ||= begin
        cmd = "cardano-cli query tip --#{chain}"
        stdout, stderr, status = Open3.capture3(cmd)
        raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus != 0
        current_slot = JSON.parse(stdout)['slot']
        current_slot.to_i + 3600
      end
    end

    def tx_out
      if token
        "#{destination_address}+#{ada}+\"#{token.amount} #{token.policy_id}.#{token.hex_name}\""
      else
        "#{destination_address}+#{ada}"
      end
    end

    def tx_ins_str
      tx_ins.map { |utxo| "--tx-in #{utxo.tx_hash}##{utxo.tx_ix}" }.join(" ")
    end

    def tx_ins
      @tx_ins ||= begin
        total = 0
        utxos = []
        payment_address.utxos.sort_by(&:ada).each do |utxo|
          break if total >= ada + 1_000_000
          total += utxo.ada.to_i
          utxos << utxo
          utxo
        end
        utxos
      end
    end

    def change_tx_out(fee: 0)
      amount = tx_ins.sum {|tx_in| tx_in.ada.to_i}
      remaining_lovelace = amount - ada - fee.to_i
      tokens = tx_ins.map(&:tokens).flatten
      if token
        matched_token = tokens.find do |t|
          t.policy_id == token.policy_id && t.hex_name == token.hex_name
        end
        total_token_amount = matched_token.amount.to_i - token.amount.to_i
        matched_token.amount = total_token_amount.to_s
        tokens.delete_if do|t|
          t.policy_id == token.policy_id && t.hex_name == token.hex_name
        end
        tokens << matched_token if matched_token.amount.to_i > 0
      end
      if tokens.any?
        token_args = tokens.map do |token|
          "\"#{token.amount} #{token.policy_id}.#{token.hex_name}\""
        end.join('+')
        "#{change_address}+#{remaining_lovelace}+#{token_args}"
      else
        "#{change_address}+#{remaining_lovelace}"
      end
    end
  end
end
