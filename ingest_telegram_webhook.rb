require 'json'
require 'yaml'
require 'aws-sdk-lambda'

$config = YAML.load_file('./config.yml').freeze

def handle(event:, context:)
  puts 'Received event:'
  p event

  http_request_json_payload = JSON.parse(event['body'])

  invoke_state_machine http_request_json_payload

  {
    statusCode: 204
  }
end

def invoke_state_machine(event)
  lambda_client = Aws::Lambda::Client.new(region: ENV['AWS_REGION'])

  response = lambda_client.invoke({
    function_name: "translation-bot-#{ENV['STAGE']}-Translate",
    invocation_type: 'Event',
    log_type: 'None',
    payload: event.to_json
  })
end
