require 'json'
require 'yaml'
require 'uri'
require 'net/http'
require 'openssl'
require 'aws-sdk-states'
require_relative './errors'

$config = YAML.load_file('./config.yml').freeze

def handle(event:, context:)
  puts "Received event:"
  p event
  puts "Context:"
  p context
  puts "ENV:"
  p ENV

  body = JSON.parse(event['body'])

  $chat_id = body['message']['chat']['id']
  $chat_type = body['message']['chat']['type']
  $user_message_id = body['message']['message_id']
  $user_message_text = body['message']['text']

  case $chat_type
  when 'private'
    invoke_state_machine handle_private_message(body)
  when 'group'
    invoke_state_machine handle_group_chat_message(body)
  end

  {
    statusCode: 204
  }
end


def handle_private_message(event)
  # If starting the conversation with the bot, respond with a helpful message
  return {
    chat_id: $chat_id,
    message_to_send: 'Hey there! Add me to a group chat and I\'ll translate messages for you. Simply reply with "/t" to any message and I\'ll translate it into English. Alternatively, forward me any message and I\'ll translate it into English.',
    reply_to_message_id: $user_message_id,
  } if $user_message_text == '/start'

  # Automatically translate any message sent to the bot
  {
    chat_id: $chat_id,
    message_to_translate: $user_message_text,
    reply_to_message_id: $user_message_id,
  }
end

def handle_group_chat_message(event)
  return unless $user_message_text == '/t'

  if event['message'].key? 'reply_to_message'
    reply_to_message_id = event['message']['reply_to_message']['message_id']
    reply_to_message_text = event['message']['reply_to_message']['text']

    {
      chat_id: $chat_id,
      message_to_translate: reply_to_message_text,
      reply_to_message_id: reply_to_message_id,
    }
  else
    {
      chat_id: $chat_id,
      message_to_send: 'You must reply to a message with "/t" in order for me to translate it.',
      reply_to_message_id: $user_message_id,
    }
  end
end

def invoke_state_machine(event)
  states_client = Aws::States::Client.new(region: ENV['AWS_REGION'])

  response = states_client.start_execution({
    state_machine_arn: ENV['TRANSLATION_BOT_STATE_MACHINE_ARN'],
    input: event.to_json
  })
end
