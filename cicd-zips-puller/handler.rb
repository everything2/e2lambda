require 'json'

def lambda_handler(args)
  event = args[:event]
  context = args[:context]

  pp event
  {"statusCode": "200", "headers": {"Content-Type": "application/json"}, "body": {"result": "OK"}.to_json}
end
