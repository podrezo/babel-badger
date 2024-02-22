require_relative './errors'

class TelegramWebhook
  attr_reader :chat_id, :user_message_id, :user_message_text, :reply_to_message_id, :reply_to_message_text
  def initialize(event, listen_string, telegram_service, openai_service)
    @event = event
    @listen_string = listen_string
    @telegram_service = telegram_service
    @openai_service = openai_service

    @chat_id = event.dig('message', 'chat', 'id')
    @user_message_id = event.dig('message', 'message_id')
    @user_message_text = event.dig('message', 'text') || event.dig('message', 'caption')
    @reply_to_message_id = event.dig('message', 'reply_to_message', 'message_id')
    @reply_to_message_text = event.dig('message', 'reply_to_message', 'text') || event.dig('message', 'reply_to_message', 'caption')
  end

  def process
    raise StandardError.new("Invalid webhook body: #{@event.to_json}") unless valid?

    handle_private_message if private_chat?
    handle_group_chat_message if group_chat?
  rescue TranslationException => error
    @telegram_service.send_message(@chat_id, "I encountered a problem while trying to translate your text.\n\nERROR: #{error.message}", @user_message_id)
  end

  def valid?
    return false unless @event.key?('message')
    return false unless @event['message'].key?('chat')

    true
  end

  private

  def handle_private_message
    # If starting the conversation with the bot, respond with a helpful message
    return @telegram_service.send_message(@chat_id, welcome_message) if @user_message_text == '/start'

    # Automatically translate any message sent to the bot
    translation = @openai_service.translate(@user_message_text)
    @telegram_service.send_message(@chat_id, translation, @user_message_id)
  end

  def handle_group_chat_message
    return unless message_contains_listen_string?

    if reply?
      translation = @openai_service.translate(@reply_to_message_text)
      # Reply to the original message instead of the message that tagged the bot
      @telegram_service.send_message(@chat_id, translation, @reply_to_message_id)
    else
      message_to_translate = @user_message_text.sub(@listen_string, '').strip

      if message_to_translate.empty?
        response_message = <<-RESPONSE
I did not detect any message to translate.

If you were replying to a message that needs translating, check that "conversation history" is enabled for this group.
        RESPONSE
        @telegram_service.send_message(@chat_id, response_message, @user_message_id)
        return
      end

      translation = @openai_service.translate(message_to_translate)
      @telegram_service.send_message(@chat_id, translation, @user_message_id)
    end
  end

  def private_chat?
    chat_type == 'private'
  end

  def group_chat?
    chat_type == 'group'
  end

  def chat_type
    @event.dig('message', 'chat', 'type')
  end

  def reply?
    @event['message'].key? 'reply_to_message'
  end

  def message_contains_listen_string?
    # User message text may not be defined. The 'message' may have been that a user joined a group chat
    @user_message_text&.include?(@listen_string)
  end

  def welcome_message
    'Hey there! I will translate messages into English. You can either forward me messages to me from other conversations, type stuff directly to me, or add me to a group conversation and tag me in a reply to a message.'
  end
end
