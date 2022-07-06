class Server
  def initialize(word)
    @answer = word
  end

  def answer
    @answer
  end

  def parse_guess(guess_str)
    response = %w[n n n n n]
    guess = guess_str.split('')
    answer = @answer.split('')
    green_letters = []
    yellow_letters = []

    (0..4).each do |i|
      if answer[i] == guess[i]
        response[i] = 'y'
        green_letters.push(guess[i])
      end
    end

    (0..4).each do |i|
      letter = guess[i]
      answer_count = answer.count(letter)
      found_count = green_letters.count(letter) + yellow_letters.count(letter)
      if answer_count > found_count && (response[i] != 'y')
        response[i] = 'm'
        yellow_letters.push(letter)
      end
    end
    response.join('')
  end
end