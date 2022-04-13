module Cnifty
  class Utxo
    attr_reader :raw_tx, :tx_hash, :tx_ix, :ada
    alias_method :index, :tx_ix
    alias_method :id, :tx_hash

    def initialize(raw_tx)
      @raw_tx = raw_tx
      @tx_hash, @tx_ix, @ada = raw_tx.split(' ')
    end

    def tokens
      @tokens ||= raw_tx.split(' + ')[1..-1].map do |token_set|
        token_set = token_set.split(' ')
        next if token_set.one?
        policy_id = token_set[1].split('.').first
        hex_name = token_set[1].split('.').last
        Token.new amount: token_set[0], policy_id: policy_id, hex_name: hex_name
      end.compact
    end

    def to_h
      {
        tx_hash: tx_hash.to_s,
        tx_ix: tx_ix,
        ada: ada,
        raw_tx: raw_tx
      }
    end
  end
end
