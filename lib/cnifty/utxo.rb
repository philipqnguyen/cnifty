module Cnifty
  class Utxo
    attr_reader :raw_tx, :tx_hash, :tx_ix, :amount, :token
    alias_method :index, :tx_ix
    alias_method :id, :tx_hash

    def initialize(raw_tx)
      @raw_tx = raw_tx
      @tx_hash, @tx_ix, @amount, @token = raw_tx.split(' ')
    end

    def to_h
      {
        tx_hash: tx_hash.to_s,
        tx_ix: tx_ix,
        token: token,
        amount: amount,
        raw_tx: raw_tx
      }
    end
  end
end
