require 'json'
require 'yaml'
require 'uri'
require 'net/http'
require 'openssl'

$config = YAML.load_file('./config.yml').freeze

def send_message(event:, context:)
  puts "Received event:"
  p event

  return unless event&.key? 'chat_id'

  payload = {
    chat_id: event['chat_id'],
    text: event['message_to_send'],
    reply_to_message_id: event['reply_to_message_id']
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
