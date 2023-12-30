require 'json'
require 'yaml'

$config = YAML.load_file('./config.yml').freeze

def authorize(event:, context:)
  {
    isAuthorized: token_valid?(event['identitySource']&.first)
  }
end

def token_valid?(token)
  token == $config['telegram_secret_webhook_token']
end
