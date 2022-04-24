require 'json'

# rubocop:disable ClassLength
class Wordle
  MAX_LENGTH = 5

  def initialize(opts = {})
    @options = opts
    dir = File.dirname(__FILE__)
    @possible_answers = File.read(File.join(dir, 'possible_answers.txt')).split
    @guess_word_list = File.read(File.join(dir, 'possible_answers.txt')).split
    @guess_word_list.concat(File.read(File.join(dir, 'guess_word_list.txt')).split)
    @guess_word_list.uniq!
    @guesses = 0
    @found = false
    @broke = false
    create_word_arrays
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

  def guesses
    @guesses
  end

  def guess(word)
    @current_guess = word
  end

  # Sets the minimum count for a letter
  # Check if the value has already been set. If so, select the max value
  # of previous versus massed in count
  def set_min_letter_count(letter, count)
    @letter_counts[letter][:min] = [@letter_counts[letter][:min] ? @letter_counts[letter][:min] : 0, count].max
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
      case answer[i]
      when 'y'
        @found_letters[i] = @current_guess[i]
        green_letters.push(@current_guess[i])
      when 'm'
        @maybe_letters[i] << @current_guess[i]
        yellow_letters.push(@current_guess[i])
      end
    end

    # parse again in order to handle N letters
    # rubocop:disable Style/CombinableLoops
    (0..4).each do |i|
      letter = @current_guess[i]
      case answer[i]
      when 'n'
        if (green_letters.count(letter) + yellow_letters.count(letter)).zero?
          @excluded_letters.push(@current_guess[i])
        else
          @letter_counts[letter][:max] = green_letters.count(letter) + yellow_letters.count(letter)
        end
      when 'm'
        set_min_letter_count(letter, green_letters.count(letter) + yellow_letters.count(letter))
      when 'y'
        set_min_letter_count(letter, green_letters.count(letter) + yellow_letters.count(letter))
      end
    end

    create_regex_pattern
    # Keep possible answers clean
    @possible_answers.each do |word|
      @possible_answers -= [word] unless eligible?(word)
    end

    hidden_known_letters if find_hidden_letters?

    return unless debug?

    puts "Pattern: #{@regex_pattern}"
    puts "Max Counts: #{@max_counts}"
    puts "Min Counts: #{@min_counts}"
  end

  private

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

  # How many letters, regardless of position, are found?
  def found_letters_count
    (@letter_counts.reject { |_letter, count_hash| count_hash[:min].nil? }).count
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

  def manual_debug?
    @possible_answers.length < 100
  end

  def create_word_arrays
    @max_counts = @options.key?(:max_counts) ? @options[:max_counts] : {}

    @min_counts = @options.key?(:min_counts) ? @options[:min_counts] : {}
    @found_letters = @options.key?(:found_letters) ? @options[:found_letters] : [nil, nil, nil, nil, nil]
    @excluded_letters = @options.key?(:excluded_letters) ? @options[:excluded_letters] : []

    @letter_counts = {}
    ('a'..'z').each do |letter|
      @letter_counts[letter] = { 'min': nil, 'max': nil }
    end

    @maybe_letters = [[], [], [], [], []]
  end

  def regex_for_index(index)
    if @found_letters[index]
      @found_letters[index]
    elsif !@maybe_letters[index].empty?
      "[^#{@maybe_letters[index].join('')}#{@excluded_letters.join('')}]"
    elsif !@excluded_letters.empty?
      "[^#{@excluded_letters.join('')}]"
    else
      '[a-z]'
    end
  end

  def create_regex_pattern
    regex_pattern = ''
    (0..MAX_LENGTH - 1).each do |index|
      regex_pattern << regex_for_index(index)
    end
    @regex_pattern = regex_pattern
  end

  def fancy_create_regex_pattern
    regex_pattern = '^(?='
    (0..MAX_LENGTH - 1).each do |index|
      regex_pattern << regex_for_index(index)
    end
    regex_pattern << ')'

    @letter_counts.each do |letter, letter_counts|

      found_min = !letter_counts[:min].nil?
      found_max = !letter_counts[:max].nil?

      next unless found_min || found_max

      letter_count = found_max ? letter_counts[:max] : letter_counts[:min]

      # If a min count, regex should be (?=.*p.*p.*) given two p
      # If a max count, regex should be (?=[^r]*r[^r]*r[^r]*) given two r
      count_regex = "[^#{letter}]*(#{letter}[^#{letter}]*){#{letter_count}}"

      puts "Count regex 2 for letter #{letter}: #{count_regex}"


      regex_pattern << "(?=#{count_regex})"
    end
    regex_pattern << "[a-z]{5}$"
    puts regex_pattern
    @regex_pattern = regex_pattern
  end

  def eligible?(word)
    return false unless word.match?(@regex_pattern)
    return false unless contains_included?(word)

    true
  end

  # Return a distribution of letters that are still possible
  # Given the word ?atch, this should return: p m w (for patch, match, watch). h and c (hatch and catch) shouldn't be
  # returned because those letters were already found
  def possible_letters
    puts "Going into HUNTER MODE!" if debug?
    possible_letters = empty_distribution
    @possible_answers.each do |word|
      word_to_hash(word).each do |index, letter|
        next if @found_letters[index] # Don't count letters at known positions
        next unless @letter_counts[letter][:max].nil? # Don't count letters that are already at max value
        next unless @letter_counts[letter][:min].nil? # This will cause this hash to be empty if all letters have been found

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
      letter_hash.delete(i) if @found_letters[i]
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
      letter_hash.each do |i, value|
        @found_letters[i] = value
      end
    end
  end

  # Look over possible guesses, and rates them according to the given distribution
  def rate_words
    create_regex_pattern
    create_distribution

    @possibilities = {}

    word_list = @possible_answers

    case found_letters_count
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
      next if @maybe_letters[index].include?(letter)
      next unless @letter_counts[letter][:max].nil?
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
      puts "#{letter} got #{@distribution[letter]}" if debug?
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
      next if @found_letters[index]

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
      next if limit_distribution_to_eligible_words && !eligible?(word)

      positional_distribution_by_letter(word)
      distribution_by_letter(word)
    end
  end

  # Create a filename safe string representation of the found_letters array
  def found_letters_filename
    pattern_string = ''
    @found_letters.each do |this_pattern|
      pattern_string << this_pattern.match?('[a-z]') ? this_pattern : '?'
    end
    pattern_string
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

  # Does the given word contain any excluded letters?
  def contains_excluded?(word)
    @max_counts.each do |letter, count|
      return true if word.count(letter) > count
    end
    false
  end

  def word_contains_unknown_only(word)
    word.each_char do |letter|
      return false if letter_known?(letter)
      return false if word.count(letter) > 1
    end
    true
  end

  def letter_known?(letter)
    return true if @found_letters.include?(letter)
    return true unless @letter_counts[letter][:max].nil? # TODO - does this make sense?
    return true unless @letter_counts[letter][:min].nil?

    false
  end

  # Does the given word include all the included letters?
  def contains_included?(word)
    @letter_counts.each do |letter, letter_counts|

      found_min = !letter_counts[:min].nil?
      found_max = !letter_counts[:max].nil?

      if found_max
        return false unless word.count(letter) == letter_counts[:max]
      elsif found_min
        return false if word.count(letter) < letter_counts[:min]
      end
    end
    true
  end
end
