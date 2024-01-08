require_relative '../lib/openai'
require_relative '../lib/telegram'
require_relative '../lib/telegram_webhook'

describe TelegramWebhook do
  let(:telegram_service) { instance_double(Telegram) }
  let(:openai_service) { instance_double(OpenAI, translate: 'FAKE TRANSLATED STRING') }
  let(:listen_string) { '@BabelBadgerBot' }

  context 'private message' do
    let!(:event){
      {
        'update_id' => 332517284,
        'message' => {
          'message_id' => 80,
          'from' => {
            'id' => 123,
            'is_bot' => false,
            'first_name' => 'CoolGuy',
            'username' => 'cool_guy_88',
            'language_code' => 'en'
          },
          'chat' => {
            'id' => 42,
            'first_name' => 'CoolGuy',
            'username' => 'cool_guy_88',
            'type' => 'private'
          },
          'date' => 1704072694,
          'text' => nil # To be set in the specific test
        }
      }
    }

    it 'should return a message to translate' do
      event['message']['text'] = 'Guten tag'

      expect(openai_service).to receive(:translate).with('Guten tag').and_return('FAKE TRANSLATED STRING')
      expect(telegram_service).to receive(:send_message).with(42, 'FAKE TRANSLATED STRING', 80)

      TelegramWebhook.new(event, listen_string, telegram_service, openai_service).process
    end

    it 'should respond to /start with a welcome message' do
      event['message']['text'] = '/start'

      expect(openai_service).not_to receive(:translate)
      expect(telegram_service).to receive(:send_message).with(42, 'Hey there! I will translate messages into English. You can either forward me messages to me from other conversations, type stuff directly to me, or add me to a group conversation and tag me in a reply to a message.')

      TelegramWebhook.new(event, listen_string, telegram_service, openai_service).process
    end
  end

  context 'group chat' do
    it 'should return a message to translate when being tagged in a reply' do
      event = {
        'update_id' => 332517285,
        'message' => {
          'message_id' => 82,
          'from' => {
            'id' => 123,
            'is_bot' => false,
            'first_name' => 'CoolGuy',
            'username' => 'cool_guy_88',
            'language_code' => 'en'
          },
          'chat' => {
            'id' => -585720080,
            'title' => 'Cool Boys Club',
            'type' => 'group',
            'all_members_are_administrators' => true
          },
          'date' => 1704161289,
          'reply_to_message' => {
            'message_id' => 27,
            'from' => {
              'id' => 678,
              'is_bot' => false,
              'first_name' => 'AnotherCoolGuy',
              'username' => 'xx_cool_guy_42_xx',
              'language_code' => 'en'
            },
            'chat' => {
              'id' => -585720080,
              'title' => 'Cool Boys Club',
              'type' => 'group',
              'all_members_are_administrators' => true
            },
            'date' => 1704056898,
            'text' => '你要干什么？'
          },
          'text' => '@BabelBadgerBot',
          'entities' => [
            {
              'offset' => 0,
              'length' => 15,
              'type' => 'mention'
            }
          ]
        }
      }

      expect(openai_service).to receive(:translate).with('你要干什么？').and_return('FAKE TRANSLATED STRING')
      expect(telegram_service).to receive(:send_message).with(-585720080, 'FAKE TRANSLATED STRING', 27)

      TelegramWebhook.new(event, listen_string, telegram_service, openai_service).process
    end

    it 'should respond to a non-reply if tagged' do
      event = {
        'update_id' => 332517285,
        'message' => {
          'message_id' => 82,
          'from' => {
            'id' => 123,
            'is_bot' => false,
            'first_name' => 'CoolGuy',
            'username' => 'cool_guy_88',
            'language_code' => 'en'
          },
          'chat' => {
            'id' => -585720080,
            'title' => 'Cool Boys Club',
            'type' => 'group',
            'all_members_are_administrators' => true
          },
          'date' => 1704161289,
          'text' => '你要干什么？@BabelBadgerBot',
          'entities' => [
            {
              'offset' => 0,
              'length' => 15,
              'type' => 'mention'
            }
          ]
        }
      }

      expect(openai_service).to receive(:translate).with('你要干什么？').and_return('FAKE TRANSLATED STRING')
      expect(telegram_service).to receive(:send_message).with(-585720080, 'FAKE TRANSLATED STRING', 82)

      TelegramWebhook.new(event, listen_string, telegram_service, openai_service).process
    end

    it 'should not respond if not tagged' do
      event = {
        'update_id' => 332517285,
        'message' => {
          'message_id' => 82,
          'from' => {
            'id' => 123,
            'is_bot' => false,
            'first_name' => 'CoolGuy',
            'username' => 'cool_guy_88',
            'language_code' => 'en'
          },
          'chat' => {
            'id' => -585720080,
            'title' => 'Cool Boys Club',
            'type' => 'group',
            'all_members_are_administrators' => true
          },
          'date' => 1704161289,
          'text' => '你要干什么？@SomeoneElse',
          'entities' => [
            {
              'offset' => 0,
              'length' => 15,
              'type' => 'mention'
            }
          ]
        }
      }

      expect(openai_service).not_to receive(:translate)
      expect(telegram_service).not_to receive(:send_message)

      TelegramWebhook.new(event, listen_string, telegram_service, openai_service).process
    end
  end

  context 'error case' do
    it 'should raise if no message is detected' do
      event = {
        'update_id' => 332517285,
      }

      expect {
        TelegramWebhook.new(event, listen_string, telegram_service, openai_service).process
      }.to raise_error(StandardError, /^Invalid webhook body/)
    end

    it 'should raise if no message is detected' do
      event = {
        'update_id' => 332517285,
        'message' => {
          'message_id' => 82,
          'from' => {
            'id' => 123,
            'is_bot' => false,
            'first_name' => 'CoolGuy',
            'username' => 'cool_guy_88',
            'language_code' => 'en'
          },
          'date' => 1704161289,
          'text' => '你要干什么？@BabelBadgerBot',
          'entities' => [
            {
              'offset' => 0,
              'length' => 15,
              'type' => 'mention'
            }
          ]
        }
      }

      expect {
        TelegramWebhook.new(event, listen_string, telegram_service, openai_service).process
      }.to raise_error(StandardError, /^Invalid webhook body/)
    end
  end
end
