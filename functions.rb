require 'json'

# @possible_answers is what wordle uses as the word you have to guess
@possible_answers = File.read('possible_answers.txt').split

# @possible_guesses are the words you can type to guess
possible_guesses = File.read('guess_word_list.txt').split
@possible_guesses = possible_guesses + @possible_answers
@possible_guesses = @possible_answers

@excluded_letters = []
@maybe_letters = [[], [], [], [], []]
@exact_counts = {}
@included_letters = {}
@found_letters = %w[? ? ? ? ?]

@found = false

MAX_LENGTH = 5

# Holds letters and counts of those letters
def empty_distribution
  distribution = {}
  ('a'..'z').each do |letter|
    distribution[letter] = [0, 0, 0, 0, 0]
  end
  distribution
end

# Holds a map of character positions with character counts in it
def empty_positional_distribution
  positional_distribution = {}
  (0..MAX_LENGTH-1).each do |position|
    positional_distribution[position.to_s] = empty_distribution
  end
  positional_distribution
end

# Returns word as a hash with index as key and letter as value
def word_to_hash(word)
  i = 0
  this_hash = {}
  word.each_char do |letter|
    this_hash[i] = letter
    i += 1
  end
  this_hash
end

def create_regex_safe_string
  pattern_string = ''
  @found_letters.each do |this_pattern|
    if this_pattern.match?('[a-z]')
      pattern_string << this_pattern
    else
      pattern_string << '?'
    end
  end
  pattern_string
end

def create_regex_pattern
  regex_pattern = ''
  (0..MAX_LENGTH-1).each do |index|
    if @found_letters[index].match?('[a-z]')
      regex_pattern << @found_letters[index]
    elsif @maybe_letters[index].length > 0
      excluded = @maybe_letters[index].join('')
      regex_pattern << "[^#{excluded}]"
    else
      regex_pattern << '[a-z]'
    end
  end
  regex_pattern
end

# Creates a map of how likely letters are to be at a certain position
# IE, given words cat and cow:
# c is 2 likely to be at position 0
def create_word_distribution
  positional_distribution = empty_positional_distribution

  regex_pattern = create_regex_pattern

  @possible_answers.each do |word|
    next unless word.match?(regex_pattern)

    char_occurance = {}
    word_to_hash(word).each do |index, letter|
      if char_occurance.key?(letter)
        char_occurance[letter] += 1
      else
        char_occurance[letter] = 0
      end
      occurance = char_occurance[letter]
      positional_distribution[index.to_s][letter][occurance] += 1
    end
  end
  positional_distribution
end

# Looks for an existing pattern matching what is passed
# Load it if it exists
# Create it if it doesn't
def load_or_create_distribution
  create_word_distribution
end

def contains_excluded?(word)
  @exact_counts.each do |letter, count|
    return true if word.count(letter) > count
  end
  false
end

def contains_included?(word)
  @included_letters.each do |letter, count|
    return false if word.count(letter) < count
    # return false unless word.include?(letter)
  end
  true
end

# Look over possible guesses, and rates them according to the given distribution
def rate_words
  distribution = load_or_create_distribution
  regex_pattern = create_regex_pattern
  @possibilities = {}

  @possible_guesses.each do |word|
    rating = 0
    next unless word.match?(regex_pattern)
    next if contains_excluded?(word)
    next unless contains_included?(word)


    char_occurance = {}
    word_to_hash(word).each do |index, letter|
      if char_occurance.key?(letter)
        char_occurance[letter] += 1
      else
        char_occurance[letter] = 0
      end
      occurance = char_occurance[letter]
      rating += distribution[index.to_s][letter][occurance]
    end
    @possibilities[word] = rating
  end
end

def top_rated_word
  (@possibilities.min_by { |k, v| -v })[0]
end

def remove_word_from_guesses
  @possible_guesses.delete(@current_guess)
  @possible_guesses.join("\n")
  File.open('guess_word_list.txt', 'w') do |f|
    f.write(@possible_guesses.join("\n"))
  end
end

def parse_answer(answer)
  answer = answer.downcase
  if answer == 'xxxxx'
    remove_word_from_guesses
    return
  end

  if answer == 'yyyyy'
    puts 'Congrats!! Found the word!!'
    @found = true
  end

  @included_letters = {} # Reset hash

  # parse over first time to create special Y cases
  i = 0
  answer.each_char do |letter|
    case letter
    when 'y'
      @found_letters[i] = @current_guess[i]
      if @included_letters.key?(@current_guess[i])
        @included_letters[@current_guess[i]] += 1
      else
        @included_letters[@current_guess[i]] = 1
      end
    end
    i += 1
  end

  # Again for other cases
  i = 0
  answer.each_char do |letter|
    case letter
    when 'm'
      if @included_letters.key?(@current_guess[i])
        @included_letters[@current_guess[i]] += 1
      else
        @included_letters[@current_guess[i]] = 1
      end
      @maybe_letters[i] << @current_guess[i]
    end
    i += 1
  end

  # Again for other cases
  i = 0
  answer.each_char do |letter|
    case letter
    when 'n'
      if @included_letters.key?(@current_guess[i])
        @exact_counts[@current_guess[i]] = @included_letters[@current_guess[i]]
      else
        @exact_counts[@current_guess[i]] = 0
      end
    end
    i += 1
  end

  # puts "Pattern: #{create_regex_pattern}"
  # puts "Excluded: #{@exact_counts}"
  # puts "Included: #{@included_letters}"
end

while !@found
  rate_words
  @current_guess = top_rated_word

  puts "Try the word `#{@current_guess}` (out of #{@possibilities.length} words)"
  puts "How'd it do? (Y for yes, N for no, M for Maybe, xxxxx for not a word)"
  parse_answer(gets.chomp)
end
