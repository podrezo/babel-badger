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
  detect_languages_prompt = <<~PROMPT
  You must detect languages in the user's input.
  You can only respond with ISO 639-1 language codes, separated by commas, for each language detected in the user's input.
  Any languages that do not have a corresponding ISO 639-1 code must be ignored.
  Anything that is unintelligible as a natural language is to be ignored.
  If the entire message is unintelligible then respond with an empty string.
  PROMPT

  language_codes = chatgpt(detect_languages_prompt, message_to_translate).downcase.strip

  if language_codes == ''
    event.merge(message_to_send: 'I do not understand this language, sorry.')
  elsif language_codes.strip == 'en'
    event.merge(message_to_send: 'This message is already entirely in English, sorry. Try a message that contains another language.')
  else
    language_list = language_codes.split(',')
                                  .map(&:strip)
                                  .map { |code| LANGUAGE_CODE_TO_LANGUAGE_NAME[code] }
                                  .join(', ')

    translation_prompt = <<~PROMPT
    You are a translator and you can only respond with translations of the user's input.
    You will translate into English but you can only translate the following languages: #{language_list}.
    Anything that is not in one of those languages should just be repeated back as-is.
    PROMPT

    translated_message = chatgpt(translation_prompt, message_to_translate)

    response_to_user = <<~RESPONSE
    I have translated your message into English from the following detected languages: #{language_list}.

    #{translated_message}
    RESPONSE

    event.merge(message_to_send: response_to_user)
  end
end

# This is a separate lambda that simply handles the failure case (after retry) if this could not be translated or OpenAI API is down
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

def chatgpt(system_prompt, user_input)
  payload = {
    "model": "gpt-3.5-turbo",
    "messages": [
      {
        "role": "system",
        "content": system_prompt
      },
      {
        "role": "user",
        "content": user_input
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
end

# ISO-639-1 language codes
LANGUAGE_CODE_TO_LANGUAGE_NAME = {
  'aa' => 'Afar',
  'ab' => 'Abkhazian',
  'ae' => 'Avestan',
  'af' => 'Afrikaans',
  'ak' => 'Akan',
  'am' => 'Amharic',
  'an' => 'Aragonese',
  'ar' => 'Arabic',
  'as' => 'Assamese',
  'av' => 'Avaric',
  'ay' => 'Aymara',
  'az' => 'Azerbaijani',
  'ba' => 'Bashkir',
  'be' => 'Belarusian',
  'bg' => 'Bulgarian',
  'bh' => 'Bihari languages',
  'bi' => 'Bislama',
  'bm' => 'Bambara',
  'bn' => 'Bengali',
  'bo' => 'Tibetan',
  'br' => 'Breton',
  'bs' => 'Bosnian',
  'ca' => 'Catalan; Valencian',
  'ce' => 'Chechen',
  'ch' => 'Chamorro',
  'co' => 'Corsican',
  'cr' => 'Cree',
  'cs' => 'Czech',
  'cu' => 'Church Slavic; Old Slavonic; Church Slavonic; Old Bulgarian; Old Church Slavonic',
  'cv' => 'Chuvash',
  'cy' => 'Welsh',
  'da' => 'Danish',
  'de' => 'German',
  'dv' => 'Divehi; Dhivehi; Maldivian',
  'dz' => 'Dzongkha',
  'ee' => 'Ewe',
  'el' => 'Greek',
  'en' => 'English',
  'eo' => 'Esperanto',
  'es' => 'Spanish; Castilian',
  'et' => 'Estonian',
  'eu' => 'Basque',
  'fa' => 'Persian',
  'ff' => 'Fulah',
  'fi' => 'Finnish',
  'fj' => 'Fijian',
  'fo' => 'Faroese',
  'fr' => 'French',
  'fy' => 'Western Frisian',
  'ga' => 'Irish',
  'gd' => 'Gaelic; Scottish Gaelic',
  'gl' => 'Galician',
  'gn' => 'Guarani',
  'gu' => 'Gujarati',
  'gv' => 'Manx',
  'ha' => 'Hausa',
  'he' => 'Hebrew',
  'hi' => 'Hindi',
  'ho' => 'Hiri Motu',
  'hr' => 'Croatian',
  'ht' => 'Haitian; Haitian Creole',
  'hu' => 'Hungarian',
  'hy' => 'Armenian',
  'hz' => 'Herero',
  'ia' => 'Interlingua (International Auxiliary Language Association)',
  'id' => 'Indonesian',
  'ie' => 'Interlingue; Occidental',
  'ig' => 'Igbo',
  'ii' => 'Sichuan Yi; Nuosu',
  'ik' => 'Inupiaq',
  'io' => 'Ido',
  'is' => 'Icelandic',
  'it' => 'Italian',
  'iu' => 'Inuktitut',
  'ja' => 'Japanese',
  'jv' => 'Javanese',
  'ka' => 'Georgian',
  'kg' => 'Kongo',
  'ki' => 'Kikuyu; Gikuyu',
  'kj' => 'Kuanyama; Kwanyama',
  'kk' => 'Kazakh',
  'kl' => 'Kalaallisut; Greenlandic',
  'km' => 'Central Khmer',
  'kn' => 'Kannada',
  'ko' => 'Korean',
  'kr' => 'Kanuri',
  'ks' => 'Kashmiri',
  'ku' => 'Kurdish',
  'kv' => 'Komi',
  'kw' => 'Cornish',
  'ky' => 'Kirghiz; Kyrgyz',
  'la' => 'Latin',
  'lb' => 'Luxembourgish; Letzeburgesch',
  'lg' => 'Ganda',
  'li' => 'Limburgan; Limburger; Limburgish',
  'ln' => 'Lingala',
  'lo' => 'Lao',
  'lt' => 'Lithuanian',
  'lu' => 'Luba-Katanga',
  'lv' => 'Latvian',
  'mg' => 'Malagasy',
  'mh' => 'Marshallese',
  'mi' => 'Maori',
  'mk' => 'Macedonian',
  'ml' => 'Malayalam',
  'mn' => 'Mongolian',
  'mr' => 'Marathi',
  'ms' => 'Malay',
  'mt' => 'Maltese',
  'my' => 'Burmese',
  'na' => 'Nauru',
  'nb' => 'Bokmål, Norwegian; Norwegian Bokmål',
  'nd' => 'Ndebele, North; North Ndebele',
  'ne' => 'Nepali',
  'ng' => 'Ndonga',
  'nl' => 'Dutch; Flemish',
  'nn' => 'Norwegian Nynorsk; Nynorsk, Norwegian',
  'no' => 'Norwegian',
  'nr' => 'Ndebele, South; South Ndebele',
  'nv' => 'Navajo; Navaho',
  'ny' => 'Chichewa; Chewa; Nyanja',
  'oc' => 'Occitan (post 1500)',
  'oj' => 'Ojibwa',
  'om' => 'Oromo',
  'or' => 'Oriya',
  'os' => 'Ossetian; Ossetic',
  'pa' => 'Panjabi; Punjabi',
  'pi' => 'Pali',
  'pl' => 'Polish',
  'ps' => 'Pushto; Pashto',
  'pt' => 'Portuguese',
  'qu' => 'Quechua',
  'rm' => 'Romansh',
  'rn' => 'Rundi',
  'ro' => 'Romanian; Moldavian; Moldovan',
  'ru' => 'Russian',
  'rw' => 'Kinyarwanda',
  'sa' => 'Sanskrit',
  'sc' => 'Sardinian',
  'sd' => 'Sindhi',
  'se' => 'Northern Sami',
  'sg' => 'Sango',
  'si' => 'Sinhala; Sinhalese',
  'sk' => 'Slovak',
  'sl' => 'Slovenian',
  'sm' => 'Samoan',
  'sn' => 'Shona',
  'so' => 'Somali',
  'sq' => 'Albanian',
  'sr' => 'Serbian',
  'ss' => 'Swati',
  'st' => 'Sotho, Southern',
  'su' => 'Sundanese',
  'sv' => 'Swedish',
  'sw' => 'Swahili',
  'ta' => 'Tamil',
  'te' => 'Telugu',
  'tg' => 'Tajik',
  'th' => 'Thai',
  'ti' => 'Tigrinya',
  'tk' => 'Turkmen',
  'tl' => 'Tagalog',
  'tn' => 'Tswana',
  'to' => 'Tonga (Tonga Islands)',
  'tr' => 'Turkish',
  'ts' => 'Tsonga',
  'tt' => 'Tatar',
  'tw' => 'Twi',
  'ty' => 'Tahitian',
  'ug' => 'Uighur; Uyghur',
  'uk' => 'Ukrainian',
  'ur' => 'Urdu',
  'uz' => 'Uzbek',
  've' => 'Venda',
  'vi' => 'Vietnamese',
  'vo' => 'Volapük',
  'wa' => 'Walloon',
  'wo' => 'Wolof',
  'xh' => 'Xhosa',
  'yi' => 'Yiddish',
  'yo' => 'Yoruba',
  'za' => 'Zhuang; Chuang',
  'zh' => 'Chinese',
  'zu' => 'Zulu',
}.freeze
