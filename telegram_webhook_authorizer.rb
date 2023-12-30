require 'json'
require 'yaml'
require 'uri'
require 'net/http'
require 'openssl'
require_relative './errors'

$config = YAML.load_file('./config.yml').freeze

def authorize(event:, context:)
  puts event

  # {
  #   isAuthorized: token_valid?(event['identitySource']&.first)
  # }
  {
    'principalId': 'abcdef',
    'policyDocument': {
      'Version': '2012-10-17',
      'Statement': [
        {
          'Action': 'execute-api:Invoke',
          'Effect': token_valid?(event['authorizationToken']) ? 'Allow' : 'Deny',
          'Resource': 'arn:aws:execute-api:us-east-1:234147186957:lubrmkpxll/*'
        }
      ]
    },
    'context': {
      'exampleKey': 'exampleValue'
    }
  }
end

def token_valid?(token)
  token == $config['telegram_secret_webhook_token']
end
