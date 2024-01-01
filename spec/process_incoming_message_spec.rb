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
          'text' => 'Guten tag'
        }
      }
    }
    it 'should return a message to translate' do
      result = handle(event: event, context: nil)

      expect(result).to eq({
        chat_id: 42,
        message_to_translate: 'Guten tag',
        reply_to_message_id: 80,
      })
    end
  end
end
