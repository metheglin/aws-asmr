require 'fileutils'
require 'aws/asmr'

module Aws
  module ASMR
    class Alias < Struct.new(:arn, :access_key_id, :secret_access_key, :profile, keyword_init: true)

      PATH = "#{Aws::ASMR::ROOT}/alias"

      class << self
        def parse(lines)
          lines = lines.map(&:strip).select{! _1.start_with?('#')}
          arr = lines.reduce([]) do |acc,line|
            m = line.match(/\A\[([^\[\]]+)\]\z/)
            if m
              acc << [m[1], []]
            else
              alias_name, alias_props = acc.last
              if alias_name
                k, v = line.split('=').map(&:strip)
                if k and v
                  alias_props << [k, v]
                end
              end
            end
            acc
          end
          arr.map{|k,v| [k,v.to_h]}.select{|k,v| v["arn"] and !v["arn"].empty?}.to_h
        end

        def base
          @base ||= begin
            if File.exists?(PATH)
              parse(File.readlines(PATH))
            else
              {}
            end
          end
        end

        def first
          k,v = base.first
          get(k)
        end

        def get(alias_name)
          base[alias_name] && new(base[alias_name])
        end
      end

      def set_environment_variables!
        if access_key_id and !access_key_id.empty?
          ENV["AWS_ACCESS_KEY_ID"] = access_key_id
          ENV["AWS_SECRET_ACCESS_KEY"] = secret_access_key
        elsif profile and !profile.empty?
          ENV["AWS_PROFILE"] = profile
        end
      end
    end
  end
end
