require 'json'
require 'tempfile'
require 'securerandom'
require 'open3'

module Cnifty
  class Policy

    def id
      generate
      @policy_id
    end

    def skey
      generate
      @skey
    end

    def vkey
      generate
      @vkey
    end

    def script
      generate
      @script
    end

  private

    def generate
      @generated ||= begin
        `cardano-cli address key-gen \
        --verification-key-file #{vkey_file.path} \
        --signing-key-file #{skey_file.path}
        `

        @skey = skey_file.read
        @vkey = vkey_file.read
        @script = script_content
        script_file.write @script
        script_file.close
        @policy_id = generate_policy_id
      ensure
        destroy_files
      end
    end

    def generate_policy_id
      cmd = "cardano-cli transaction policyid --script-file #{script_file.path}"
      stdout, stderr, status = Open3.capture3(cmd)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus != 0
      stdout.chomp
    end

    def script_content
      @script_content ||= %Q(
        {
          "type": "all",
          "scripts": [
            {
              "type": "before",
              "slot": #{slot}
            },
            {
              "type": "sig",
              "keyHash": "#{key_hash}"
            }
          ]
        }
      )
    end

    def slot
      cmd = "cardano-cli query tip --#{chain}"
      stdout, stderr, status = Open3.capture3(cmd)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus != 0
      current_slot = JSON.parse(stdout)['slot']
      current_slot.to_i + 60
    end

    def key_hash
      cmd = "cardano-cli address key-hash --payment-verification-key-file #{vkey_file.path}"
      stdout, stderr, status = Open3.capture3(cmd)
      raise CardanoNodeError, stderr if !stderr.empty? || status.exitstatus != 0
      stdout.chomp
    end

    def chain
      'testnet-magic 1097911063'
    end

    def seed
      @seed ||= SecureRandom.uuid
    end

    def skey_file
      @skey_file ||= Tempfile.new("policy_#{seed}.skey")
    end

    def vkey_file
      @vkey_file ||= Tempfile.new("policy_#{seed}.vkey")
    end

    def script_file
      @script_file ||= Tempfile.new("policy_#{seed}.script")
    end

    def destroy_files
      skey_file.close
      skey_file.unlink
      vkey_file.close
      vkey_file.unlink
      script_file.close
      script_file.unlink
    end
  end
end
