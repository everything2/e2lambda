#!/usr/bin/env ruby
#frozen_string_literal: true

require 'aws-sdk-s3'
require 'archive-zip'

def http_response(code, message)
  {"statusCode": code, "headers": {"Content-Type": "application/json"}, "body": {"message": message}.to_json}
end

def lambda_handler(args)
  s3client = Aws::S3::Client.new(region: ENV['AWS_DEFAULT_REGION'])
  event = args[:event]

  pp event

  return http_response(200, "OK")
end
