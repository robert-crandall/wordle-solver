require_relative './wordle.rb'
require 'getoptlong'

opts = GetoptLong.new(
  [ '--interactive', '-i', GetoptLong::NO_ARGUMENT ]
)

def interactive_mode
  @wordle = Wordle.new()
  until @wordle.found?
    puts "Possibilities: #{@wordle.possible_answers.length}"
    puts "Try one of these words:"
    # puts "(Hint: first letter of top word is #{@wordle.top_ten_words[0][0]}#{@wordle.top_ten_words[0][1]})"

    puts @wordle.top_ten_words
    puts
    puts "Which word did you select?"
    @wordle.guess(gets.chomp)
    puts "How'd it do? (Y for yes, N for no, M for Maybe, xxxxx for not a word)"
    @wordle.parse_answer(gets.chomp)
  end
end

opts.each do |opt, arg|
  case opt
  when '--interactive'
    interactive_mode
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


