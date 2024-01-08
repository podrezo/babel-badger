require 'json'
require 'uri'
require 'net/http'
require 'openssl'
require_relative './errors'

class OpenAI
  def initialize(api_key)
    @api_key = api_key
  end

  def translate(message_to_translate)
    translation_prompt = <<~PROMPT
    You are a translator that translates to English from any real, human-spoken language that is intelligible to you.

    You will only translate input that is delimited by triple backticks.

    Your output will always be in JSON format with the keys 'translation' and 'languages' where 'translation' is the translated text, in English and 'languages' is an array of the detected languages in the input. Here is an example:

    Input: "Guten tag"
    Output:
    {
      "translation": "Good day",
      "languages": ["German"]
    }

    ```#{message_to_translate}```
    PROMPT

    response = invoke_completions_api(translation_prompt)

    response_to_user_message(response)
  end

  private

  def response_to_user_message(translation_json_string)
    translation_data = JSON.parse(translation_json_string)

    raise TranslationException.new('The translation service did not provide the output in the correct format.') unless valid_translation_response?(translation_data)

    translated_message = translation_data['translation']
    languages = translation_data['languages'].map(&:strip)

    raise TranslationException.new('I do not understand this language, sorry.') if languages.empty?
    raise TranslationException.new('This message is already entirely in English, sorry. Try a message that contains another language.') if only_english?(languages)

    response_to_user = <<~RESPONSE
    I have translated your message into English from the following detected languages: #{languages.join(', ')}.

    #{translated_message}
    RESPONSE

    response_to_user
  rescue JSON::ParserError
    raise TranslationException.new('The translation service failed to provide a translation. Trying again may help.')
  end

  def only_english?(languages)
    languages.map(&:downcase).include?('english') && languages.length == 1
  end

  def valid_translation_response?(translation_hash)
    (translation_hash.keys - ['translation', 'languages']).empty?
  end

  def invoke_completions_api(user_prompt, system_prompt = nil)
    payload = {
      model: 'gpt-3.5-turbo',
      messages: []
    }

    payload[:messages].push(role: 'system', content: system_prompt) if system_prompt
    payload[:messages].push(role: 'user', content: user_prompt)

    url = URI('https://api.openai.com/v1/chat/completions')

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(url)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"
    request.body = payload.to_json

    response = http.request(request)

    response_body = JSON.parse(response.read_body)
    puts 'Response from ChatGPT:'
    p response_body
    chatgpt_response = response_body['choices'][0]['message']['content']
  end
end
