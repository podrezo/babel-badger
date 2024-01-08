require 'json'
require 'uri'
require 'net/http'
require 'openssl'
require_relative './errors'

class Telegram
  def initialize(api_key)
    @api_key = api_key
  end

  def send_message(chat_id, message, reply_to_message_id = nil)
    payload = {
      chat_id: chat_id,
      text: message,
    }

    payload.merge!(reply_to_message_id: reply_to_message_id) unless reply_to_message_id.nil?

    url = URI("https://api.telegram.org/bot#{@api_key}/sendMessage")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(url)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)
  end
end
