require 'open3'

module Cnifty
  class Utxos
    include Enumerable
    extend Forwardable
    attr_reader :payment_address, :chain
    delegate [:last, :[]] => :all

    def initialize(payment_address)
      @payment_address = payment_address
      @chain = 'testnet-magic 1097911063'
    end

    def all
      @all ||= fetch.map {|raw_tx| Utxo.new raw_tx}
    end

    def each(&block)
      all.each(&block)
    end

  private

    def fetch
      cmd = "cardano-cli query utxo --address #{payment_address} --#{chain}"
      stdout, stderr, status = Open3.capture3(cmd)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus != 0
      results = stdout&.split("\n")
      raise CardanoNodeError, stdout unless success?(results)
      results[2..-1]
    end

    def success?(raw_utxos)
      return false if raw_utxos.nil?
      return false if raw_utxos.empty?
      return false unless raw_utxos.count >= 2
      return false unless raw_utxos[0].include? 'TxHash'
      return false unless raw_utxos[1].include? '--------'
      true
    end
  end
end
