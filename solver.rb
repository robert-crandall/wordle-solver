require_relative './wordle.rb'
require_relative './server.rb'
require 'getoptlong'

opts = GetoptLong.new(
  [ '--interactive', '-i', GetoptLong::NO_ARGUMENT ],
  [ '--hint', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--date', '-d',  GetoptLong::OPTIONAL_ARGUMENT ]
)

def interactive_mode
  @wordle = Wordle.new()
  until @wordle.found?
    puts "Possibilities: #{@wordle.possible_answers.length}"
    puts "Try one of these words:"
    # puts "(Hint: first letter of top word is #{@wordle.top_ten_words[0][0]}#{@wordle.top_ten_words[0][1]})"

    puts @wordle.top_words
    puts
    puts "Which word did you select?"
    @wordle.guess(gets.chomp)
    puts "How'd it do? (Y for yes, N for no, M for Maybe, xxxxx for not a word)"
    @wordle.parse_answer(gets.chomp)
  end
end

def find_word_date
  @wordle = Wordle.new()
  puts @wordle.word_date(@test_word)
end

def get_hint
  wordle = Wordle.new()
  # puts "Todays word: #{wordle.todays_word}"
  server = Server.new(wordle.todays_word)
  (1..1).each do |i|
    top_score = 0
    top_word = ""
    word_scores = {}
    wordle.top_words(words: 50).each do |word|
      this_score = server.score_guess(word)
      word_scores[word] = this_score
      if this_score > top_score
        top_score = this_score
        top_word = word
      end
    end
    puts "top guess from round #{i}: #{top_word}"
    wordle.guess(top_word)
    puts "Ranked choice round 1:"
    puts word_scores.select { |_, score| score.positive? }
    wordle.parse_answer(server.parse_guess(top_word))
  end
  puts "And top 10 words after that hint:"
  puts wordle.top_words
  # (1..2).each do |i|
  #   top_rated_word = wordle.top_rated_word
  #   puts "Starting a guess with #{top_rated_word}, which matches as #{server.parse_guess(top_rated_word)}"
  #   wordle.parse_answer(server.parse_guess(top_rated_word))
  #   puts "Hint ##{i}: #{wordle.top_ten_words}"
  # end
end

opts.each do |opt, arg|
  case opt
  when '--interactive'
    interactive_mode
    exit!
  when '--date'
    @test_word = arg
    find_word_date
    exit!
  when '--hint'
    get_hint
    exit!
  end
end

options = {
  "quiet": true
}
@wordle = Wordle.new(options)
until @wordle.found?
  current_guess = @wordle.top_rated_word

  puts "Possibilities: #{@wordle.possible_answers.length}"
  if @wordle.finding_letters?
    puts "Remaining words: #{@wordle.possible_answers}"
  end
  puts "Try the word `#{current_guess}`"
  puts "How'd it do? (Y for yes, N for no, M for Maybe, xxxxx for not a word)"
  @wordle.parse_answer(gets.chomp)
end
