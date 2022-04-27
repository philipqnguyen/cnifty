require 'tempfile'
require 'securerandom'

module Cnifty
  class Nft
    attr_reader :destination_address,
                :change_address,
                :payment_address,
                :name,
                :attributes,
                :image,
                :policy,
                :era,
                :chain,
                :protocol

    def initialize(destination_address:,
                   change_address:,
                   payment_address:,
                   name:,
                   attributes:,
                   image:,
                   policy:)
      @protocol = Protocol.new
      @destination_address = destination_address
      @change_address = change_address
      @payment_address = payment_address
      @name = name
      @attributes = attributes
      @image = image
      @policy = policy
      @chain = 'testnet-magic 1097911063'
      @era = 'alonzo-era'
    end

    def mint
      write_metadata
      write_policy_file
      write_policy_skey_file
      write_payment_address_skey_file
      write_protocol_file
      execute_raw_transaction_command
      fee = execute_calculate_min_fee_command
      execute_raw_transaction_with_fees_command(fee)
      execute_sign_raw_transaction_command
      execute_submit_command
      execute_read_transaction_id
    ensure
      transaction_file_raw.close
      transaction_file_raw.unlink
      transaction_file_signed.close
      transaction_file_signed.unlink
      policy_file.close
      policy_file.unlink
      policy_skey_file.close
      policy_skey_file.unlink
      payment_address_skey_file.close
      payment_address_skey_file.unlink
      metadata_file.close
      metadata_file.unlink
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

    def metadata_file
      @metadata_file ||= Tempfile.new "metadata_#{seed}.json"
    end

    def policy_file
      @policy_file ||= Tempfile.new "policy_#{seed}.script"
    end

    def policy_skey_file
      @policy_skey_file ||= Tempfile.new "policy_#{seed}.skey"
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

    def write_policy_skey_file
      File.write policy_skey_file, policy.skey
    end

    def write_policy_file
      File.write policy_file, policy.script
    end

    def write_metadata
      File.write(metadata_file, metadata.to_json)
    end

    def metadata
      {
        '721' => {
          policy.id => {
            formatted_name => {name: name, image: image}.merge(attributes)
          }
        }
      }
    end

    def execute_raw_transaction_command
      cmd = """
      cardano-cli transaction build-raw \
        --invalid-hereafter #{policy.before_slot} \
        --#{era} \
        --fee 0 \
        #{tx_ins_str} \
        --tx-out #{tx_out} \
        --tx-out #{change_tx_out(fee: 0)} \
        #{mints} \
        --minting-script-file #{policy_file.path} \
        --metadata-json-file #{metadata_file.path} \
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
        --witness-count 2 \
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
        --invalid-hereafter #{policy.before_slot} \
        --#{era} \
        --fee #{fee} \
        #{tx_ins_str} \
        --tx-out #{tx_out} \
        --tx-out #{change_tx_out(fee: fee)} \
        #{mints} \
        --minting-script-file #{policy_file.path} \
        --metadata-json-file #{metadata_file.path} \
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
        --signing-key-file #{policy_skey_file.path} \
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
      stdout.chomp
    end

    def tx_ins_str
      tx_ins.map { |utxo| "--tx-in #{utxo.tx_hash}##{utxo.tx_ix}" }.join(" ")
    end

    def tx_ins
      @tx_ins ||= begin
        total = 0
        utxos = []
        payment_address.utxos.sort_by(&:ada).each do |utxo|
          break if total >= min_ada + 1_000_000
          total += utxo.ada.to_i
          utxos << utxo
          utxo
        end
        utxos
      end
    end

    def tx_out
      "#{destination_address}+#{min_ada}+\"1 #{policy.id}.#{hex_name}\""
    end

    def min_ada
      1_500_000
    end

    def formatted_name
      name.gsub(' ', '')
    end

    def hex_name
      formatted_name.unpack('H*').last
    end

    def mints
      args = [name].map do |token|
        "1 #{policy.id}.#{hex_name}"
      end.join(" + ")
      "--mint=\"#{args}\""
    end

    def change_tx_out(fee: 0)
      amount = tx_ins.sum {|tx_in| tx_in.ada.to_i}
      remaining_lovelace = amount - min_ada - fee.to_i
      tokens = tx_ins.map(&:tokens).flatten
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
