require "optparse"

module Aws::ASMR
  module Options
    def partition(args)
      _idx, asmr_args, command_args = args.reduce([1, [], []]) do |acc,i|
        idx, _, _ = acc
        unless i.start_with?('-')
          idx = 2
          acc[0] = idx
        end
        acc[idx] << i
        acc
      end
      [asmr_args, command_args]
    end

    def parse(args)
      options = {}
      OptionParser.new do |opts|
        # opts.banner = "Usage: asmr [options]"
        opts.banner = <<~EOS
          Usage: asmr [options] [command] [arg...]
          

        EOS

        opts.on("-nNAME", "--name=NAME", "Name to perform assume role with ARN or ALIAS") do |name|
          options[:name] = name
        end

        opts.on("-h", "--help", "Prints this help") do
          puts opts
          exit(0)
        end
        opts.on("--version", "Prints version") do
          options[:version] = true
        end
        opts.on("--clear", "Clear cache") do
          options[:clear] = true
          # require "aws/asmr/version"
          # puts Aws::ASMR::VERSION
          # exit(0)
        end
      end.parse(args)
      options
    end

    module_function :partition, :parse
  end
end
