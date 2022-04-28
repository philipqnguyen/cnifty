require 'json'
require 'open3'

module Cnifty
  class Tip
    attr_reader :chain

    def initialize
      @chain = 'testnet-magic 1097911063'
    end

    def slot
      cmd = "cardano-cli query tip --#{chain}"
      stdout, stderr, status = Open3.capture3(cmd)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus != 0
      current_slot = JSON.parse(stdout)['slot']
      current_slot.to_i
    end
  end
end
