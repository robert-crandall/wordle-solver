require_relative './wordle.rb'


possible_answers = File.read('possible_answers.txt').split
test_name = 'baseline'

filename = "./cache/#{test_name}.json"
small_filename = "./cache/#{test_name}_small.json"

if(File.exist?(filename))
  puts 'Full results already exists for this test run! Delete it or rename the test'
  puts "Hint: `rm #{filename}`"
  exit!
end

unless File.exist?(small_filename)
  puts 'No small test was run. Running that now.'
  possible_answers = File.read('possible_answers_small.txt').split
  filename = small_filename
end



@word_results = {}

def count_answer_tries(answer)
  wordle = Wordle::Wordle.new({"quiet": true})
  server = Wordle::Server.new(answer)
  # puts "Looking for #{server.answer}"
  i = 0

  until wordle.found?
    i += 1
    top_word = wordle.top_rated_word
    #puts "Trying #{top_word}"
    wordle.parse_answer(server.parse_guess(top_word))
  end
  if i > 6
    puts "Word failed, #{server.answer} took #{i} tries"
  end
  @word_results[answer] = i
end


possible_answers.each do |answer|
  self.count_answer_tries(answer)
end


hash_average = @word_results.values.sum(0.0) / @word_results.length
puts "Hash average: #{hash_average}"

failed = @word_results.select { |_word, tries| tries > 6 }

results = {
  test_name => {
    'average' => hash_average,
    'failed_count' => failed.length,
    'failed' => failed,
    'words' => @word_results
  }
}

File.open(filename,'w') do |f|
  f.write(JSON.pretty_generate(results))
end






