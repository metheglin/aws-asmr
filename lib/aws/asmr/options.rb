require "optparse"
require "aws/asmr"

module Aws::ASMR
  module Options
    # Parses asmr's own options from the head of argv and returns
    # [options, command_args]. Parsing stops at the first non-option argument
    # (or after a literal "--"), so anything from there on -- including
    # arguments like --filter that start with "-" -- belongs to the command:
    #
    #   asmr --name=foo aws ec2 describe-instances --filter '...'
    #   asmr --name foo aws sts get-caller-identity
    #   asmr -n foo -- aws sts get-caller-identity
    def parse(argv)
      options = {}
      command_args = argv.dup
      OptionParser.new do |opts|
        # opts.banner = "Usage: asmr [options]"
        opts.banner = <<~EOS
          You can use ALIAS to shortcut name input by setting it at #{Aws::ASMR::ROOT}/alias

          Usage: asmr [options] [--] [command] [arg...]
                 asmr local [NAME|--unset]   Pin NAME (alias or ARN) to the current directory
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
        opts.on("--verbose", "Prints verbose") do
          options[:verbose] = true
        end
        opts.on("--clear", "Clear cache") do
          options[:clear] = true
        end
      end.order!(command_args)
      [options, command_args]
    end

    module_function :parse
  end
end
