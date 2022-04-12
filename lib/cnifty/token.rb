module Cnifty
  class Token
    attr_reader :amount, :policy, :name, :hex_name

    def initialize(amount:, token:)
      @amount = amount
      @policy = token.split('.').first
      @hex_name = token.split('.').last
      @name = [@hex_name].pack('H*')
    end
  end
end
