#!./bin/perl -w

use strict;

sub http_response
{
  my ($code, $message) = @_;
  return encode_json({"statusCode" => $code, "headers" => {"Content-Type" => "application/json"}, "body" => {"message" => $message}});
}

sub lambda_handler
{
  my ($event) = @_;
  http_response(200, "Hello World - Layer test!");
}

1;
