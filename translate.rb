require 'yaml'
require_relative './lib/telegram_webhook'
require_relative './lib/openai'
require_relative './lib/telegram'



def handle(event:, context:)
  puts "Event:"
  p event

  config = YAML.load_file('./config.yml').freeze

  raise StandardError.new('Missing "message" key in event payload') unless event.key?('message')
  raise StandardError.new('Missing "message.chat" key in event payload') unless event['message'].key?('chat')

  openai_service = OpenAI.new(config['openai_api_key'])
  telegram_service = Telegram.new(config['telegram_bot_key'])
  webhook = TelegramWebhook.new(event, config['listen_string'], telegram_service, openai_service)
  webhook.process
end
