require_relative 'word_matcher'

# rubocop:disable ClassLength
class Wordle
  MAX_LENGTH = 5
  attr_reader :guesses

  def initialize(opts = {})
    @options = opts
    @guesses = 0
    @found = false
    @broke = false
    set_word_lists
  end

  def top_rated_word
    rate_words
    @guesses += 1
    check_breakage
    @current_guess = (@possibilities.min_by { |k, v| -v })[0]
    @current_guess
  end

  def top_ten_words
    rate_words
    @possibilities.sort_by { |k, v| -v }.first(10).to_h.keys
  end

  def found?
    @found || @broke
  end

  def broke?
    @broke
  end

  def possible_answers
    @possible_answers
  end

  def guess(word)
    @current_guess = word
  end

  # rubocop:disable MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def parse_answer(answer)
    answer = answer.downcase
    if answer == 'xxxxx'
      puts "Removing word from list isn't implemented, sorry!"
      exit!
    end

    if answer == 'yyyyy'
      puts 'Congrats!! Found the word!!' unless quiet?
      @found = true
    end

    green_letters = []
    yellow_letters = []

    # parse over first time to create counts of found letters
    (0..4).each do |i|
      letter = @current_guess[i]
      case answer[i]
      when 'y'
        word_matcher.set_found_letter(letter, i)
        green_letters.push(letter)
      when 'm'
        word_matcher.set_maybe_letter(letter, i)
        yellow_letters.push(letter)
      end
    end

    # parse again in order to handle N letters
    # rubocop:disable Style/CombinableLoops
    (0..4).each do |i|
      letter = @current_guess[i]
      count = green_letters.count(letter) + yellow_letters.count(letter)

      case answer[i]
      when 'n'
        if count.zero?
          word_matcher.set_excluded_letter(letter)
        else
          word_matcher.set_max_letter_count(letter, count)
        end
      when 'm'
        word_matcher.set_min_letter_count(letter, green_letters.count(letter) + yellow_letters.count(letter))
      when 'y'
        word_matcher.set_min_letter_count(letter, green_letters.count(letter) + yellow_letters.count(letter))
      end
    end

    word_matcher.refresh_regex_pattern

    # Keep possible answers clean
    @possible_answers.each do |word|
      @possible_answers -= [word] unless word_matcher.word_eligible?(word)
    end


    hidden_known_letters if find_hidden_letters?

    return unless debug?

    puts "Pattern: #{word_matcher.regex_pattern}"
    puts "Letter Counts: #{word_matcher.letter_counts}"
  end

  private

  def word_matcher
    @word_matcher ||= WordMatch.new(@options)
  end

  # When looking at word list possibilities, exclude words that are ineligible
  # When true:
  # Small avg count goes from 4 to 3.5, no change on failed counts
  # Full avg count from 3.75 to 3.6, failure from 17 to 14
  def limit_distribution_to_eligible_words
    true
  end

  # Prefer rating unknown letters in order to maximize guessing
  # 2 - small goes 4 to 1; full goes 14 to 11
  # 3 - full goes 14 to 15
  def maximize_unknown_letters?
    guesses < 2 && found_letters_count < 5
  end

  # Did something break? If so, print some debug information
  def check_breakage
    if @guesses > 8
      puts "Something broke. Sorry bro."
      puts "  Regex: #{@regex_pattern}"
      @broke = true
    end
  end

  # This option reduced speed by 10% and didn't improve counts
  def find_hidden_letters?
    true
  end

  def quiet?
    @options.key?(:quiet)
  end

  def debug?
    @options.key?(:debug) || @guesses > 6
  end


  # Return a distribution of letters that are still possible
  # Given the word ?atch, this should return: p m w (for patch, match, watch). h and c (hatch and catch) shouldn't be
  # returned because those letters were already found
  def possible_letters
    puts "Going into LETTER HUNTER MODE!" if debug?
    possible_letters = empty_distribution
    @possible_answers.each do |word|
      word_to_hash(word).each do |index, letter|
        next if word_matcher.found_letters[index] # Don't count letters at known positions
        next unless word_matcher.letter_counts[letter][:max].nil? # Don't count letters that are already at max value
        next unless word_matcher.letter_counts[letter][:min].nil? # This will cause this hash to be empty if all letters have been found

        possible_letters[letter] += 1
      end
    end
    possible_letters
  end

  # Look through remaining words and see if there are any letters that exist for every word
  # Given hatch and talen, it should find that A needs to be in second position
  def hidden_known_letters
    return if @possible_answers.length == 1

    first_word = @possible_answers[0]
    letter_hash = word_to_hash(first_word)

    # Only look at unknown letters
    (0..4).each do |i|
      letter_hash.delete(i) if word_matcher.found_letters[i]
    end

    # Loop through remaining words
    @possible_answers.each do |word|
      break if letter_hash.empty?

      letter_hash.each do |i, value|
        letter_hash.delete(i) if word[i] != value
      end
    end

    # Found some - add them to known letters!
    unless letter_hash.empty?
      letter_hash.each do |i, letter|
        word_matcher.set_found_letter(letter, i)
      end
    end
  end

  # Look over possible guesses, and rates them according to the given distribution
  def rate_words
    word_matcher.refresh_regex_pattern
    create_distribution

    @possibilities = {}

    word_list = @possible_answers

    case word_matcher.found_letters_count
    when 0..2
      word_list = @possible_answers
      word_list.each do |word|
        @possibilities[word] = rate_word_positional(word)
      end
    when 3..4
      if @possible_answers.length == 1
        word = @possible_answers[0]
        @possibilities[word] = 100
        return
      end
      # Find a word that matches the most letters
      @distribution = possible_letters
      needed_letters = @distribution.select { |_letter, count| count > 0 }
      if debug?
        puts "trying to rule out: #{needed_letters.to_s}"
      end

      # All letters are found. Just try out remaining words.
      if needed_letters.empty?
        puts "Needed letters is empty. Trying out remaining words." if debug?
        word_list = @possible_answers
        word_list.each do |word|
          @possibilities[word] = rate_word_nonpositional(word)
        end
        return
      end

      # Try to rule out remaining letters. Use full word list for this.
      word_list = @guess_word_list
      word_list.each do |word|
        @possibilities[word] = rate_word_for_uniquness(word)
      end
    else
      word_list.each do |word|
        @possibilities[word] = rate_word_nonpositional(word)
      end
    end

  end

  def rate_word_for_uniquness(word)
    rating = 0
    seen_letters = []

    word_to_hash(word).each do |index, letter|
      next if word_matcher.maybe_letters[index].include?(letter)
      next unless word_matcher.letter_counts[letter][:max].nil?
      next if seen_letters.include?(letter)

      rating += @distribution[letter]
      seen_letters.push(letter)
    end
    rating
  end

  def rate_word_positional(word)
    rating = 0

    word_to_hash(word).each do |index, letter|
      rating += @positional_distribution[index.to_s][letter]
    end
    rating
  end

  def rate_word_nonpositional(word)
    rating = 0
    seen_letters = []

    word_to_hash(word).each do |index, letter|
      # rating += @positional_distribution[index.to_s][letter]
      next if seen_letters.include?(letter)

      rating += @distribution[letter]
      seen_letters.push(letter)
    end
    rating
  end

  def distribution_by_positional_duplicates(word)
    char_occurance = {}
    word_to_hash(word).each do |index, letter|
      if char_occurance.key?(letter)
        char_occurance[letter] += 1
      else
        char_occurance[letter] = 0
      end
      occurance = char_occurance[letter]
      @positional_distribution[index.to_s][letter][occurance] += 1
    end
  end

  def positional_distribution_by_letter(word)
    word_to_hash(word).each do |index, letter|
      @positional_distribution[index.to_s][letter] += 1
    end
  end

  def distribution_by_letter(word)
    word_to_hash(word).each do |index, letter|
      next if word_matcher.found_letters[index]

      @distribution[letter] += 1
    end
  end

  # Creates a map of how likely letters are to be at a certain position
  # IE, given words cat and cow:
  # c is 2 likely to be at position 0
  def create_distribution
    @positional_distribution = empty_positional_distribution
    @distribution = empty_distribution

    word_list = @possible_answers

    word_list.each do |word|
      next if limit_distribution_to_eligible_words && word_matcher.word_disqualified?(word)

      positional_distribution_by_letter(word)
      distribution_by_letter(word)
    end
  end

  # Holds letters and counts of those letters
  def empty_distribution
    distribution = {}
    ('a'..'z').each do |letter|
      distribution[letter] = 0
    end
    distribution
  end

  # Holds a map of character positions with character counts in it
  def empty_positional_distribution
    positional_distribution = {}
    (0..MAX_LENGTH - 1).each do |position|
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

  def set_word_lists
    @possible_answers = File.read('possible_answers.txt').split
    @guess_word_list = File.read('possible_answers.txt').split
    @guess_word_list.concat(File.read('guess_word_list.txt').split)
    @guess_word_list.uniq!
  end
end
