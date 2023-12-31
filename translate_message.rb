require 'json'
require 'yaml'
require 'uri'
require 'net/http'
require 'openssl'

$config = YAML.load_file('./config.yml').freeze

def chatgpt_translate(event:, context:)
  puts "INPUT TO CHATGPT TRANSLATE:"
  puts event

  message_to_translate = event.delete 'message_to_translate'

  system_prompt = <<~PROMPT
  You are a translator that translates any inputs into English. You will respond with the translation of the user's message in English followed by the language that you translated it from. If the user's message is already in English, simply say "This is already in Engish."
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
        "content": message_to_translate
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

  event.merge(message_to_send: chatgpt_response)
end

def handle_translation_failure(event:, context:)
  puts 'Received event:'
  p event

  error_object = event.dig('error', 'Cause')

  error_message = if error_object && (error_hash = JSON.parse(error_object))
                    error_hash['errorMessage']
                  else
                    event.dig('error', 'Error')
                  end

  event.delete 'message_to_translate'
  event.merge(message_to_send: "Sorry! There was a problem translating your message.\n\nError:\n#{error_message}")
end
