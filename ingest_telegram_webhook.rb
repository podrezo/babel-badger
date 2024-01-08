require 'json'
require 'yaml'
require 'aws-sdk-lambda'
require_relative './lib/telegram_webhook'


def handle(event:, context:)
  config = YAML.load_file('./config.yml').freeze

  webhook_payload = JSON.parse(event['body'])

  unless TelegramWebhook.new(webhook_payload, config['listen_string'], nil, nil).valid?
    return {
      statusCode: 400,
      body: 'Invalid request'
    }
  end

  begin_async_translate_job webhook_payload

  {
    statusCode: 204
  }
rescue JSON::ParserError => e
  puts "Error parsing JSON: #{e.message}"

  {
    statusCode: 400,
    body: "Error parsing JSON: #{e.message}"
  }
end

def begin_async_translate_job(event)
  lambda_client = Aws::Lambda::Client.new(region: ENV['AWS_REGION'])

  response = lambda_client.invoke({
    function_name: "translation-bot-#{ENV['STAGE']}-Translate",
    invocation_type: 'Event',
    log_type: 'None',
    payload: event.to_json
  })
end
