require 'json'
require 'yaml'
require 'uri'
require 'net/http'
require 'openssl'
require 'aws-sdk-states'

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
  states_client = Aws::States::Client.new(region: ENV['AWS_REGION'])

  response = states_client.start_execution({
    state_machine_arn: ENV['TRANSLATION_BOT_STATE_MACHINE_ARN'],
    input: event.to_json
  })
end
