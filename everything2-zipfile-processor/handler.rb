#!/usr/bin/env ruby
#frozen_string_literal: true

require 'fileutils'
require 'aws-sdk-s3'
require 'archive/zip'
require 'find'

def http_response(code, message)
  {"statusCode": code, "headers": {"Content-Type": "application/json"}, "body": {"message": message}.to_json}
end

def lambda_handler(args)
  s3client = Aws::S3::Client.new(region: ENV['AWS_DEFAULT_REGION'])
  event = args[:event]

  bucket = event['bucket']
  zipfile = event['zipfile']

  if bucket.nil? or zipfile.nil?
    return http_response(400, "Need bucket and zipfile")
  end

  unless zipfile.match(/\.zip$/)
    zipfile = "#{zipfile}.zip"
  end

  disk_zipfile = "/tmp/#{zipfile}"
  expandir = "/tmp/expand"

  puts "Cleaning out old runs (#{disk_zipfile},#{expandir})"

  File.unlink(disk_zipfile) if File.exist? disk_zipfile
  FileUtils.rm_rf(expandir) if Dir.exist? expandir

  puts "Fetching zip file to /tmp"
  s3client.get_object(bucket: bucket, key: zipfile, response_target: disk_zipfile)
  puts "Fetching done... unzipping"
  Archive::Zip.extract(disk_zipfile, "#{expandir}/.")

  Find.find(expandir) do |item|
    next unless item.start_with?("#{expandir}/vagrant/cookbooks")
    next unless FileTest.file?(item)
    upload_key = item.dup
    upload_key.gsub!("#{expandir}/vagrant/cookbooks/","")

    puts "Uploading to #{upload_key} "
    s3client.put_object(body: File.open(item).read, bucket: "cookbooks.everything2.com", key: upload_key)
  end

  return http_response(200, "OK")
end
