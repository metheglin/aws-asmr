require "aws/asmr"
require "aws/asmr/options"
require "aws/asmr/prompt"

module Aws
  module ASMR
    # The parts shared by every asmr executable: option parsing, --version /
    # --clear, resolving the role (alias or ARN), and obtaining temporary
    # credentials via assume_role (with MFA prompt and caching).
    #
    # Each executable is just a thin wrapper that decides what to do with the
    # resolved credentials:
    #
    #   Aws::ASMR::CLI.main(ARGV) do |cache, command_args, options, asmr_alias|
    #     # ... use cache.shell_variables / build a login URL / etc.
    #   end
    module CLI
      # Parses asmr-level args, handles --version/--clear, resolves credentials
      # and yields (cache, command_args, options, asmr_alias) to the block; the
      # resolved alias is nil when an ARN was given directly. Top-level errors
      # are reported here (with a backtrace under --verbose) and exit non-zero.
      def main(argv)
        asmr_args, command_args = Options.partition(argv)
        Local.run(command_args.drop(1)) if command_args.first == "local"
        options = Options.parse(asmr_args)

        if options[:version]
          require "aws/asmr/version"
          puts VERSION
          exit(0)
        elsif options[:clear]
          Cache.destroy!
          exit(0)
        end

        prompt = Prompt.safe
        begin
          cache, asmr_alias = resolve_credentials(options, prompt)
          yield cache, command_args, options, asmr_alias
        rescue => e
          STDERR.puts e.message
          if options[:verbose]
            STDERR.puts e.backtrace
          else
            STDERR.puts "Add --verbose for more error information."
          end
          exit(1)
        end
      end

      # Resolves the role to assume (from --name/-n, the nearest .asmr pin, or an
      # interactive alias selection) and returns [cache, asmr_alias]: a Cache
      # holding temporary credentials (reusing a valid cache entry or performing
      # assume_role with an MFA prompt), and the resolved Alias (nil when an ARN
      # was given directly).
      def resolve_credentials(options, prompt)
        name = options[:name] || pinned_name || begin
          alias_keys = Alias.base.keys
          if alias_keys.empty?
            STDERR.puts "Please specify --name=ARN to assume_role or make alias at #{ROOT}/alias"
            exit(1)
          end
          prompt.select("Choose a role you're going to assume:", alias_keys)
        end

        asmr_alias = Alias.get(name)
        assume_role_arn = if asmr_alias
          asmr_alias.set_environment_variables!
          asmr_alias.arn
        else
          name
        end

        if cache = Cache.get(assume_role_arn)
          return [cache, asmr_alias]
        end

        serial_number = Aws::ASMR.detect_mfa_device_serial_number
        assume_role_args = asmr_alias ? asmr_alias.assume_role_args : {}
        if serial_number
          token_code = prompt.ask("Type MFA token code:")
          assume_role_args = assume_role_args.merge(serial_number: serial_number, token_code: token_code)
        end

        res = perform_assume_role(assume_role_arn, assume_role_args, mfa: !serial_number.nil?)
        cache = Cache.new(**res.credentials.to_h)
        cache.save!(assume_role_arn)
        [cache, asmr_alias]
      end

      # Name pinned by the nearest .asmr (see Local), validated so that a stale
      # pin fails with a clear message instead of an obscure assume_role error.
      def pinned_name
        name, file = Local.find
        return nil unless name
        Local.validate!(name, source: file)
        name
      end

      # Calls assume_role. When DurationSeconds is rejected (the role's max
      # session duration is shorter, or the source credentials are temporary so
      # role chaining caps it at 1h), retries without it -- unless an MFA code
      # was consumed, since a TOTP code cannot be reused; then it fails with
      # guidance rather than asking for another code.
      def perform_assume_role(arn, args, mfa:)
        Aws::ASMR.assume_role(arn, **args)
      rescue Aws::STS::Errors::ValidationError => e
        raise unless args[:duration_seconds] && e.message.match?(/durationseconds/i)
        hint = "assume_role with DurationSeconds=#{args[:duration_seconds]} was rejected: #{e.message}"
        if mfa
          raise "#{hint}\nLower session_duration in the alias (or raise the role's maximum session duration) and try again."
        end
        STDERR.puts "#{hint} Retrying without DurationSeconds..."
        Aws::ASMR.assume_role(arn, **args.reject { |k, _| k == :duration_seconds })
      end

      module_function :main, :resolve_credentials, :pinned_name, :perform_assume_role
    end
  end
end
