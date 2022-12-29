require 'aws-sdk-iam'
require 'aws-sdk-sts'
require 'fileutils'

module Aws
  module ASMR
    ROOT = if ENV["AWS_ASMR_ROOT"] && !ENV["AWS_ASMR_ROOT"].empty?
      Pathname.new(ENV["AWS_ASMR_ROOT"]).join('').to_s
    else
      Pathname.new(ENV['HOME']).join('.aws-asmr').to_s
    end

    # assume_role('arn', serial_number: 'serial-number', token_code: '012345')
    def assume_role(assume_role_arn, **args)
      sts = Aws::STS::Client.new(region: 'us-east-1')
      res = sts.assume_role(
        role_arn: assume_role_arn, 
        role_session_name: "aws-asmr",
        **args
      )
    end

    def detect_mfa_device_serial_number
      iam_client = Aws::IAM::Client.new(region: 'us-east-1')
      res = iam_client.list_mfa_devices
      res.mfa_devices.detect(&:serial_number)&.serial_number
    end

    module_function :assume_role, :detect_mfa_device_serial_number
  end
end

require 'aws/asmr/cache'
require 'aws/asmr/alias'
