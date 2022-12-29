require 'fileutils'
require 'aws/asmr'

module Aws
  module ASMR
    class Cache < Struct.new(:access_key_id, :secret_access_key, :session_token, :expiration, keyword_init: true)

      PATH = "#{Aws::ASMR::ROOT}/cache"

      class << self
        def base
          @base ||= begin
            if File.exists?(PATH)
              JSON.parse(File.read(PATH))
            else
              {}
            end
          end
        end

        def first
          k,v = base.first
          get(k)
        end

        def get(assume_role_arn)
          cache = base[assume_role_arn] && new(base[assume_role_arn])
          return nil unless cache
          cache.expired? ? nil : cache
        end

        def destroy!
          File.exists?(PATH) && File.delete(PATH)
        end
      end

      def expiration_time
        return nil unless expiration
        expiration.is_a?(Time) ? expiration : Time.parse(expiration)
      end

      def expired?
        return true unless expiration_time
        expiration_time < (Time.now+60*5)
      end

      def save!(assume_role_arn)
        FileUtils.mkdir_p(Pathname.new(PATH).dirname)
        self.class.base[assume_role_arn] = to_h
        File.open(PATH, 'w') do |f|
          f.puts(JSON.pretty_generate(self.class.base))
        end
      end

      def shell_variables
        {
          AWS_ACCESS_KEY_ID: access_key_id,
          AWS_SECRET_ACCESS_KEY: secret_access_key,
          AWS_SESSION_TOKEN: session_token,
        }.map{|k,v| "#{k}=#{v}"}
      end
    end
  end
end
