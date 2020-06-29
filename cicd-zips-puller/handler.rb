#!/usr/bin/env ruby

require 'json'
require 'aws-sdk-s3'
require 'openssl'
require 'net/http'

def http_response(code, message)
  {"statusCode": code, "headers": {"Content-Type": "application/json"}, "body": {"message": message}.to_json}
end

def get_github_secret(s3client)
  return s3client.get_object(bucket: "secrets.everything2.com", key: "github_webhook_secret").body.read
end

def generate_github_signature(secret, payload)
  return 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, payload)
end

def lambda_handler(args)
  s3client = Aws::S3::Client.new(region: ENV['AWS_DEFAULT_REGION'])
  event = args[:event]
  context = args[:context]

  signature = nil
  unless(event["headers"].nil?)
    signature = event["headers"]["X-Hub-Signature"]
  end

  if(signature.nil?)
    return http_response(400, "No signature found in headers")
  end

  if(event.nil? or event["body"].nil?)
    return http_response(400, "Empty POST body")
  end

  begin
    secret = get_github_secret(s3client)
  rescue Aws::S3::Errors::AccessDenied => e
    return http_response(500, "No access to Github secret")
  end
  
  if(secret.nil?)
    return http_response(500, "Could not get Github secret")
  end

  unless(generate_github_signature(secret, event["body"]).eql? signature)
    return http_response(403, "Signature does not match")
  end

  body = nil
  begin
    body = JSON.parse(event["body"])
  rescue JSON::ParserError => e
    return http_response(400, "JSON parsing failed")
  end

  html_url = nil

  if(body["repository"].nil? or body["repository"]["html_url"].nil?)
    return http_response(400, "No 'html_url' in body")
  else
    html_url = body["repository"]["html_url"]
  end

  filename = nil
  filepart = nil
  if matches = /\/([^\/]+)$/.match(html_url)
    filepart = matches[1] + '.zip'
    filename = '/tmp/' + filepart
  end

  zipurl = html_url + '/zipball/master/'

  if filename.nil?
    return http_response(400, "Could not extract filename part from html_url: '#{html_url}'")
  end

  File.write(filename, Net::HTTP.get(URI.parse(zipurl)))  

  s3client.put_object(bucket: "githubzips.everything2.com", key: filepart, body: File.open(filename).read)

  File.unlink(filename)
  http_response(200, "OK - Cloned #{zipurl}")
end
