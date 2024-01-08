class TranslationException < StandardError
  def initialize(message = 'Sorry! There was a problem translating your message.')
    super(message)
  end
end
