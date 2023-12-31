# require 'yaml'

# $config = YAML.load_file('./config.yml').freeze

def handle(event:, context:)
  puts "Event:"
  p event

  raise StandardError.new('Missing "message" key in event payload') unless event.key?('message')
  raise StandardError.new('Missing "message.chat" key in event payload') unless event['message'].key?('chat')

  $chat_id = event.dig('message', 'chat', 'id')
  $chat_type = event.dig('message', 'chat', 'type')
  $user_message_id = event.dig('message', 'message_id')
  $user_message_text = event.dig('message', 'text') || event.dig('message', 'caption')

  case $chat_type
  when 'private'
    handle_private_message(event)
  when 'group'
    handle_group_chat_message(event)
  end
end


def handle_private_message(event)
  # If starting the conversation with the bot, respond with a helpful message
  return {
    chat_id: $chat_id,
    message_to_send: 'Hey there! I will translate messages into English. You can either forward me messages to me from other conversations, type stuff directly to me, or add me to a group conversation and tag me in a reply to a message.',
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
  # The "message" may just be that a user joined the chat, so ignore those
  return unless $user_message_text&.include?($config['listen_string'])

  if event['message'].key? 'reply_to_message'
    reply_to_message_id = event.dig('message', 'reply_to_message', 'message_id')
    reply_to_message_text = event.dig('message', 'reply_to_message', 'text') || event.dig('message', 'reply_to_message', 'caption')

    {
      chat_id: $chat_id,
      message_to_translate: reply_to_message_text,
      reply_to_message_id: reply_to_message_id,
    }
  else
    message_to_translate = $user_message_text.sub($config['listen_string'], '').strip

    {
      chat_id: $chat_id,
      message_to_translate: message_to_translate,
      reply_to_message_id: $user_message_id,
    }
  end
end
