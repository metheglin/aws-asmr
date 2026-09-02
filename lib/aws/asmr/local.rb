require 'pathname'
require 'aws/asmr'

module Aws
  module ASMR
    # Per-directory pinning of the role to assume, modelled after `rbenv local`.
    #
    #   asmr local NAME      # write NAME (alias or ARN) to ./.asmr
    #   asmr local           # print the name pinned in the current directory
    #   asmr local --unset   # remove ./.asmr
    #
    # When asmr runs without --name, the nearest .asmr found in the current
    # directory or any of its parents decides the role, so the interactive
    # alias selection is skipped.
    module Local
      FILE_NAME = ".asmr"
      ARN_PATTERN = %r{\Aarn:aws[\w-]*:iam::\d{12}:role/}

      # Runs the `local` subcommand with its remaining args and exits.
      def run(args)
        if args.empty?
          name = read(Dir.pwd)
          abort "asmr: no local role configured for this directory" unless name
          puts name
        elsif args == ["--unset"]
          unset(Dir.pwd)
        elsif args.length == 1 && !args.first.start_with?('-')
          write(args.first, Dir.pwd)
        else
          abort "Usage: asmr local [NAME|--unset]"
        end
        exit(0)
      rescue RuntimeError => e
        abort e.message
      end

      def path(dir)
        File.join(dir, FILE_NAME)
      end

      # Name pinned exactly in dir (first non-empty, non-comment line), or nil.
      def read(dir)
        file = path(dir)
        return nil unless File.file?(file)
        File.readlines(file).map(&:strip).find { |l| !l.empty? && !l.start_with?('#') }
      end

      # Walks up from dir to the filesystem root and returns [name, file] of the
      # nearest .asmr, or nil when none is found.
      def find(dir = Dir.pwd)
        Pathname.new(dir).expand_path.ascend do |d|
          name = read(d.to_s)
          return [name, path(d.to_s)] if name
        end
        nil
      end

      def write(name, dir)
        validate!(name)
        File.write(path(dir), "#{name}\n")
      end

      def unset(dir)
        file = path(dir)
        File.delete(file) if File.exist?(file)
      end

      # A name must be a defined alias or a role ARN, the same way rbenv refuses
      # to pin a version that is not installed.
      def validate!(name, source: nil)
        return if Alias.get(name) || name.match?(ARN_PATTERN)
        where = source ? " (pinned at #{source})" : ""
        raise "asmr: '#{name}'#{where} is neither an alias defined at #{Alias::PATH} nor a role ARN"
      end

      module_function :run, :path, :read, :find, :write, :unset, :validate!
    end
  end
end
