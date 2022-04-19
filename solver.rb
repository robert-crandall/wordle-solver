require_relative './wordle.rb'


@wordle = Wordle::Wordle.new()

until @wordle.found?
  current_guess = @wordle.top_rated_word

  puts "Try the word `#{current_guess}`"
  puts "How'd it do? (Y for yes, N for no, M for Maybe, xxxxx for not a word)"
  @wordle.parse_answer(gets.chomp)
end



