require 'json'
require 'uri'
require 'net/http'
require 'rbconfig'
require 'aws/asmr'

module Aws
  module ASMR
    # Builds a sign-in URL for the AWS Management Console out of the temporary
    # credentials obtained by assume_role, using the AWS federation endpoint.
    # See: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_enable-console-custom-url.html
    module WebLogin
      ENDPOINT = "https://signin.aws.amazon.com/federation"
      DEFAULT_DESTINATION = "https://console.aws.amazon.com/"
      DEFAULT_ISSUER = "aws-asmr"
      # Console session duration. Up to 43200 (12h), but it must be LESS than the
      # max session duration setting of the role being assumed (default 1h), so
      # request_signin_token falls back to omitting it when the endpoint rejects it.
      DEFAULT_SESSION_DURATION = 43200

      # Exchanges the temporary credentials for a sign-in token at the federation
      # endpoint. Retries without SessionDuration when it is rejected (e.g. the
      # role's max session duration is shorter, or the credentials come from role
      # chaining, both of which make SessionDuration invalid).
      def signin_token(cache, session_duration: DEFAULT_SESSION_DURATION)
        res = request_signin_token(cache, session_duration)
        if !res.is_a?(Net::HTTPSuccess) && session_duration
          STDERR.puts "getSigninToken with SessionDuration=#{session_duration} was rejected (HTTP #{res.code}). Retrying without SessionDuration..."
          res = request_signin_token(cache, nil)
        end
        unless res.is_a?(Net::HTTPSuccess)
          raise "Federation endpoint returned HTTP #{res.code}: #{res.body}"
        end
        token = JSON.parse(res.body)["SigninToken"]
        raise "Federation endpoint did not return a SigninToken: #{res.body}" unless token
        token
      end

      # Builds the final console login URL. Valid for 15 minutes after creation.
      # The landing page defaults to the given region's console home, or the
      # global console home when no region is given (e.g. ARN passed directly).
      def signin_url(cache, region: nil, issuer: DEFAULT_ISSUER, session_duration: DEFAULT_SESSION_DURATION)
        token = signin_token(cache, session_duration: session_duration)
        build_url(
          "Action" => "login",
          "Issuer" => issuer,
          "Destination" => destination_for(region),
          "SigninToken" => token,
        )
      end

      # Console home URL to land on after sign-in.
      def destination_for(region)
        return DEFAULT_DESTINATION if region.nil? || region.empty?
        "https://#{region}.console.aws.amazon.com/console/home?region=#{region}"
      end

      # Opens the given URL in the default browser. Falls back to printing it
      # (e.g. on a headless host where no opener is available).
      def open_browser(url)
        opener = browser_opener
        if opener && system(*opener, url)
          STDERR.puts "Opened the AWS Management Console in your browser."
        else
          STDERR.puts "Open the following URL in your browser to sign in (valid for 15 minutes):"
          puts url
        end
      end

      def request_signin_token(cache, session_duration)
        session = {
          sessionId: cache.access_key_id,
          sessionKey: cache.secret_access_key,
          sessionToken: cache.session_token,
        }.to_json

        params = { "Action" => "getSigninToken", "Session" => session }
        params["SessionDuration"] = session_duration.to_s if session_duration
        Net::HTTP.get_response(URI(build_url(params)))
      end

      def build_url(params)
        uri = URI(ENDPOINT)
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      def browser_opener
        case RbConfig::CONFIG['host_os']
        when /darwin/ then ["open"]
        when /mswin|mingw|cygwin/ then ["cmd", "/c", "start", ""]
        else ["xdg-open"]
        end
      end

      module_function :signin_token, :signin_url, :destination_for, :open_browser, :request_signin_token, :build_url, :browser_opener
    end
  end
end
