module Cnifty
  class Token
    attr_reader :policy_id, :name, :hex_name
    attr_accessor :amount

    def initialize(amount:, policy_id:, hex_name:)
      @amount = amount
      @policy_id = policy_id
      @hex_name = hex_name
      @name = [hex_name].pack('H*')
    end
  end
end
