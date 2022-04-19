require_relative './wordle.rb'

require 'getoptlong'

# https://ruby-doc.org/stdlib-3.1.1/libdoc/getoptlong/rdoc/GetoptLong.html
opts = GetoptLong.new(
  [ '--backup', '-b', GetoptLong::NO_ARGUMENT ],
  [ '--test', '-t', GetoptLong::NO_ARGUMENT ],
  [ '--update', '-u', GetoptLong::NO_ARGUMENT ]
)

@wordle = Wordle::Wordle.new()

until @wordle.found?
  current_guess = @wordle.top_rated_word

  puts "Try the word `#{current_guess}`"
  puts "How'd it do? (Y for yes, N for no, M for Maybe, xxxxx for not a word)"
  @wordle.parse_answer(gets.chomp)
end


