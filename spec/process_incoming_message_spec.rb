require_relative '../process_incoming_message'

describe 'process_incoming_message' do
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

      result = handle(event: event, context: nil)

      expect(result).to eq({
        chat_id: 42,
        message_to_translate: 'Guten tag',
        reply_to_message_id: 80,
      })
    end

    it 'should respond to /start with a welcome message' do
      event['message']['text'] = '/start'

      result = handle(event: event, context: nil)

      expect(result).to eq({
        chat_id: 42,
        message_to_send: 'Hey there! I will translate messages into English. You can either forward me messages to me from other conversations, type stuff directly to me, or add me to a group conversation and tag me in a reply to a message.',
        reply_to_message_id: 80,
      })
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

      result = handle(event: event, context: nil)

      expect(result).to eq({
        chat_id: -585720080,
        message_to_translate: '你要干什么？',
        reply_to_message_id: 27,
      })
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

      result = handle(event: event, context: nil)

      expect(result).to eq({
        chat_id: -585720080,
        message_to_translate: '你要干什么？',
        reply_to_message_id: 82,
      })
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

      result = handle(event: event, context: nil)

      expect(result).to eq({})
    end
  end

  context 'error case' do
    it 'should raise if no message is detected' do
      event = {
        'update_id' => 332517285,
      }

      expect {
        handle(event: event, context: nil)
      }.to raise_error(StandardError, 'Missing "message" key in event payload')
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
        handle(event: event, context: nil)
      }.to raise_error(StandardError, 'Missing "message.chat" key in event payload')
    end
  end
end
