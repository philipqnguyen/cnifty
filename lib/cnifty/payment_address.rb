require 'tempfile'
require 'securerandom'

module Cnifty
  class PaymentAddress
    def initialize(address_literal = nil)
      @address = address_literal
    end

    def to_s
      address
    end

    def address
      generate
      @address
    end

    def skey
      generate
      @skey
    end

    def vkey
      generate
      @vkey
    end

    def utxos
      Utxos.new self
    end

  private

    def generate
      return if @address
      begin
        `cardano-cli address key-gen \
        --verification-key-file #{vkey_file.path} \
        --signing-key-file #{skey_file.path}
        `

        `cardano-cli address build \
        --payment-verification-key-file #{vkey_file.path} \
        --out-file #{address_file.path}\
        --#{chain}
        `

        @skey = skey_file.read
        @vkey = vkey_file.read
        @address = address_file.read

        self
      ensure
        destroy_files
      end
    end

    def chain
      'testnet-magic 1097911063'
    end

    def seed
      @seed ||= SecureRandom.uuid
    end

    def skey_file
      @skey_file ||= Tempfile.new("payment_#{seed}.skey")
    end

    def vkey_file
      @vkey_file ||= Tempfile.new("payment_#{seed}.vkey")
    end

    def address_file
      @address_file ||= Tempfile.new("payment_#{seed}.address")
    end

    def destroy_files
      skey_file.close
      skey_file.unlink
      vkey_file.close
      vkey_file.unlink
      address_file.unlink
      address_file.close
    end
  end
end
