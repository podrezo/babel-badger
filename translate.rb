require 'yaml'
require_relative './lib/telegram_webhook'
require_relative './lib/openai'
require_relative './lib/telegram'

def handle(event:, context:)
  config = YAML.load_file('./config.yml').freeze

  puts 'Received event:', event.to_json

  openai_service = OpenAI.new(config['openai_api_key'])
  telegram_service = Telegram.new(config['telegram_bot_key'])
  webhook = TelegramWebhook.new(event, config['listen_string'], telegram_service, openai_service)
  webhook.process
end
