#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'

require 'aws-sdk-s3'
require 'aws-sdk-lambda'
require 'archive/zip'
require 'json'

@s3client = Aws::S3::Client.new(region: 'us-west-2') 
@lambdaclient = Aws::Lambda::Client.new(region: 'us-west-2')

@lambdasource = "lambdasource.everything2.com"
@builddir = ".build"

def function_exists?(function)
  @lambdaclient.list_functions.functions.each do |func|
    return true if func['function_name'].eql? function
  end
  nil
end

Dir.glob("*") do |entry|
  if File.directory?(entry)
    next if entry.match(/^\./)
    filename = "#{entry}.zip"
    output = "#{@builddir}/#{filename}"

    if File.exists? output
      puts "Removing old file: '#{output}'"
      File.unlink(output)
    end

    puts "Creating archive: '#{output}'"
    Archive::Zip.archive(output, "#{entry}/.")

    puts "Uploading archive: '#{output}'"
    @s3client.put_object(body: File.open(output).read, key: filename, bucket: @lambdasource)
    
    if function_exists?(entry)
      puts "Updating function code: '#{entry}'"
      @lambdaclient.update_function_code(function_name: entry, s3_bucket: @lambdasource, s3_key: filename)
    end
  end
end
