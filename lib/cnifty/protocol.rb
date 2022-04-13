require 'tempfile'
require 'securerandom'

module Cnifty
  class Protocol
    def to_s
      @to_s ||= fetch
    end

  private

    def seed
      @seed ||= SecureRandom.uuid
    end

    def protocol_file
      @protocol_file ||= Tempfile.new("protocol_#{seed}.json")
    end

    def chain
      'testnet-magic 1097911063'
    end

    def fetch
      cmd = "cardano-cli query protocol-parameters --#{chain} --out-file #{protocol_file.path}"
      _stdout, stderr, status = Open3.capture3(cmd)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus != 0
      protocol_file.read
    ensure
      protocol_file.close
      protocol_file.unlink
    end
  end
end
