require 'json'
require 'yaml'
require 'uri'
require 'net/http'
require 'openssl'
require_relative './errors'

$config = YAML.load_file('./config.yml').freeze

def handle(event:, context:)
  validate_telegram_secret_token event

  body = JSON.parse(event['body'])
  chat_id = body['message']['chat']['id']
  user_message_id = body['message']['message_id']
  user_message_text = body['message']['text']

  puts "Received event:"
  p body

  case user_message_text
  when '/start'
    respond_to_telegram reply_to_message_id, chat_id, "Hey there! Add me to a group chat and I'll translate messages for you. Simply reply with '/t' to any message and I'll translate it into English."
  when '/t'
    if body['message'].key? 'reply_to_message'
      reply_to_message_id = body['message']['reply_to_message']['message_id']
      reply_to_message_text = body['message']['reply_to_message']['text']

      translated_text = chatgpt_translate reply_to_message_text
      respond_to_telegram reply_to_message_id, chat_id, translated_text
    else
      respond_to_telegram user_message_id, chat_id, 'You must reply to a message with "/t" in order for me to translate it.'
    end
  end

  {
    statusCode: 200,
    body: {
      success: true
    }.to_json
  }

rescue InvalidTokenError
  {
    statusCode: 403,
    body: {
      message: 'Invalid telegram token',
    }.to_json
  }
end

def validate_telegram_secret_token(event)
  header_value = event['headers']['x-telegram-bot-api-secret-token']

  raise InvalidTokenError.new unless header_value == $config['telegram_secret_webhook_token']
end

def chatgpt_translate(user_message)
  system_prompt = <<~PROMPT
  You are a translator that automatically detects the source language and then translates it into English.

  Your response will always start with "Translated from [language]:" followed by two new line characters, followed by the translation of the message. [language] will be replaced with the detected language written in both the English name of the language and the name of the language in that language. For example, "Ukrainian (Українська)".

  If the message of the user is unintelligible as normal conversation (gibberish, computer code, slash commands) then simply respond with "I could not translate this message, sorry."
  PROMPT

  payload = {
    "model": "gpt-3.5-turbo",
    "messages": [
      {
        "role": "system",
        "content": system_prompt
      },
      {
        "role": "user",
        "content": user_message
      }
    ]
  }.to_json

  url = URI("https://api.openai.com/v1/chat/completions")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Post.new(url)
  request['Content-Type'] = 'application/json'
  request['Authorization'] = "Bearer #{$config['openai_api_key']}"
  request.body = payload

  response = http.request(request)

  response_body = JSON.parse(response.read_body)
  puts 'Response from ChatGPT:'
  p response_body
  chatgpt_response = response_body['choices'][0]['message']['content']

  chatgpt_response
end

def respond_to_telegram(reply_to_message_id, chat_id, response_message)
  payload = {
    chat_id: chat_id,
    text: response_message,
    reply_to_message_id: reply_to_message_id
  }.to_json

  puts "Sending message to telegram API:"
  puts payload

  url = URI("https://api.telegram.org/bot#{$config['telegram_bot_key']}/sendMessage")

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  request = Net::HTTP::Post.new(url)
  request['Content-Type'] = 'application/json'
  request.body = payload

  response = http.request(request)

  puts "Response from telegram API to sendMessage:"
  puts response.read_body
end
