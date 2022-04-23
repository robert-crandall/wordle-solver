require_relative './wordle.rb'
require 'getoptlong'

possible_answers = File.read('possible_answers.txt').split

# https://ruby-doc.org/stdlib-3.1.1/libdoc/getoptlong/rdoc/GetoptLong.html
opts = GetoptLong.new(
  [ '--name', '-n',  GetoptLong::REQUIRED_ARGUMENT ],
  [ '--small', '-s', GetoptLong::NO_ARGUMENT ],
  [ '--word', '-w',  GetoptLong::OPTIONAL_ARGUMENT ]
)

test_name = nil
@small = false
@test_word = nil
@debug = false

opts.each do |opt, arg|
  case opt
  when '--name'
    test_name = arg
  when '--small'
    @small = true
  when '--word'
    @test_word = arg
    @debug = true
  end
end


filename = "./cache/#{test_name}.json"
small_filename = "./cache/#{test_name}_small.json"

baseline_filename = './cache/baseline.json'
baselinesmall_filename = './cache/baseline_small.json'

unless File.exist?(baseline_filename)
  unless test_name == 'baseline'
    puts 'Baseline file needed before making improvements!'
    exit!
  end
end

if File.exist?(filename) && !@small
  puts 'Full results already exists for this test run! Delete it or rename the test'
  puts "Hint: `rm -f #{filename}`"
  exit!
end

if !File.exist?(small_filename) || @small
  puts 'No small test was run. Running that now.'
  possible_answers = File.read('possible_answers_small.txt').split
  filename = small_filename
  baseline_filename = baselinesmall_filename
end



@word_results = {}

def count_answer_tries(answer)
  options = {
    "quiet": true
  }
  options[:debug] = true if @debug

  wordle = Wordle::Wordle.new(options)
  server = Wordle::Server.new(answer)
  puts "Looking for #{server.answer}" if @debug
  i = 0

  until wordle.found?
    i += 1
    top_word = wordle.top_rated_word
    puts "Trying #{top_word}" if @debug
    wordle.parse_answer(server.parse_guess(top_word))
  end
  puts "Word failed, #{server.answer} took #{i} tries" if i > 6
  @word_results[answer] = i
end

starting = Process.clock_gettime(Process::CLOCK_MONOTONIC)

total_words = possible_answers.length
i = 0

possible_answers.each do |answer|
  puts "On word #{i} of #{total_words}" if i % 100 == 0
  if @test_word
    self.count_answer_tries(@test_word)
    exit!
  end
  self.count_answer_tries(answer)
  i += 1
end
ending = Process.clock_gettime(Process::CLOCK_MONOTONIC)

elapsed = ending - starting

hash_average = @word_results.values.sum(0.0) / @word_results.length
puts "Hash average: #{hash_average}"

failed = @word_results.select { |_word, tries| tries > 6 }

results = {
    'average' => hash_average,
    'execution_seconds' => elapsed.round,
    'failed_count' => failed.length,
    'failed_words' => failed,
    'all_words' => @word_results
}

if File.exist?(baseline_filename) && test_name != 'baseline'
  file = File.read(baseline_filename)
  baseline_results = JSON.parse(file)

  baseline_average = baseline_results['average']

  puts "Baseline vs #{test_name}"
  puts "Avg Count: #{baseline_results['average']} vs #{hash_average.round(2)} #{hash_average < baseline_results['average'] ? ' - Improvement!' : ''}"
  puts "Time: #{baseline_results['execution_seconds']} vs #{elapsed.round} #{elapsed.round < baseline_results['execution_seconds'] ? ' - Improvement!' : ''}"
  puts "Failed Count: #{baseline_results['failed_count']} vs #{failed.length} #{failed.length < baseline_results['failed_count'] ? ' - Improvement!' : ''}"

end


File.open(filename,'w') do |f|
  f.write(JSON.pretty_generate(results))
end






