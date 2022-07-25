require_relative 'word_matcher'
require_relative 'server'
require 'json'
require 'date'
require 'tzinfo'
require 'pry'

# rubocop:disable ClassLength
class Wordle
  MAX_LENGTH = 5
  attr_reader :guesses, :possible_answers

  def initialize(opts = {})
    @options = opts
    @guesses = 0
    @found = false
    @broke = false
    @best_word_higher = true # Ok, this is a hack. Two different word rating systems produce different results.
    @zone = TZInfo::Timezone.get('America/Los_Angeles')
    set_word_lists
  end

  def top_rated_word
    rate_words_with_group_size
    @guesses += 1
    check_breakage
    if @best_word_higher
      @current_guess = (@possibilities.min_by { |_, v| -v })[0]
    else
      @current_guess = (@possibilities.min_by { |_, v| v })[0]
    end
    @current_guess
  end

  def top_words(words: 10, random: false)
    rate_words
    if random
      @possibilities.sort_by { |_, v| -v }.first(words).to_h.keys.shuffle
    else
      @possibilities.sort_by { |_, v| -v }.first(words).to_h.keys
    end
  end

  def found?
    @found || @broke
  end

  def broke?
    @broke
  end

  def word_date(word)
    start_date.to_date + @ordered_word_list.index(word)
  end

  def todays_word
    index = @zone.now.to_date - start_date.to_date
    @ordered_word_list[index]
  end

  def guess(word)
    @current_guess = word
  end

  def finding_letters?
    finding_unique_letters?
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

    # parse over first time to create counts of found letters
    parse_found_letters(answer)

    # parse again in order to handle N letters
    parse_letter_counts(answer)

    word_matcher.refresh_regex_pattern

    # Keep possible answers clean
    @possible_answers.each do |word|
      @possible_answers -= [word] unless word_matcher.word_eligible?(word)
    end

    hidden_known_letters if find_hidden_letters?

    return unless debug?

    puts "Pattern: #{word_matcher.regex_pattern}"
    # puts "Letter Counts: #{word_matcher.letter_counts}"
  end

  private

  def word_matcher
    @word_matcher ||= WordMatch.new(@options)
  end

  # Use positional distributions and word scoring.
  # If true, the letter order matters. Will favor s in the first letter, for example
  # If false, letter order does not matter. Will only favor most used letters.
  def positional_ratings?
    return true if @needed_letters.nil?
    return false if @needed_letters.empty?

    !finding_unique_letters?
  end

  # If the goal is to find unique letters
  # This is set when trying to distinguish between hatch, match, and catch
  def finding_unique_letters?
    return false if @needed_letters.nil? || @needed_letters.empty?
    return false if @possible_answers.length <= guess_when_words_remain
    return true if word_matcher.found_letters_count >= hunt_letters

    false
  end

  def word_list
    return @guess_word_list if finding_unique_letters?

    @possible_answers
  end

  # When looking at word list possibilities, exclude words that are ineligible
  # When true:
  # Small avg count goes from 4 to 3.5, no change on failed counts
  # Full avg count from 3.75 to 3.6, failure from 17 to 14
  def limit_distribution_to_eligible_words
    true
  end

  # Which letters are still unknown?
  def needed_letters
    if @positional_ratings
      flatten_positional.select { |_letter, count| count.positive? }
    else
      @distribution.select { |_letter, count| count.positive? }
    end
  end

  # Converts a positional distribution to a flat distribution
  def flatten_positional
    flat_distribution = empty_distribution
    (0..MAX_LENGTH - 1).each do |i|
      @distribution[i.to_s].each do |letter, count|
        flat_distribution[letter] += count
      end
    end
    flat_distribution
  end

  # Did something break? If so, print some debug information
  def check_breakage
    return unless @guesses > 8

    puts 'Something broke. Sorry bro.'
    puts "  Regex: #{@regex_pattern}"
    @broke = true
  end

  # This option reduced speed by 10% and didn't improve counts
  def find_hidden_letters?
    false
  end

  def quiet?
    @options[:quiet] || false
  end

  def debug?
    @options[:debug] || @guesses > 6
  end

  # Switch to hunting unique letters at this many found letters
  def hunt_letters
    @options[:hunt_letters] || 3
  end

  # Switch to random guessing when this many words remain
  def guess_when_words_remain
    @options[:guess_count] || 2
  end

  # Return a distribution of letters that are still possible
  # Given the word ?atch, this should return: p m w (for patch, match, watch). h and c (hatch and catch) shouldn't be
  # returned because those letters were already found
  def possible_letters
    puts 'Going into LETTER HUNTER MODE!' if debug?
    possible_letters = empty_distribution
    @possible_answers.each do |word|
      word_to_hash(word).each do |index, letter|
        next if word_matcher.found_letters[index]
        next unless word_matcher.letter_counts[letter][:max].nil?

        # This will return an empty result when all letters are known, but a repeat letter needs to be found
        next unless word_matcher.letter_counts[letter][:min].nil?

        possible_letters[letter] += 1
      end
    end
    puts "Need to rule out: #{possible_letters.select { |_letter, count| count.positive? }}" if debug?
    possible_letters
  end

  # Perform actions on the Y and M letters in a guess
  def parse_found_letters(answer)
    @green_letters = []
    @yellow_letters = []
    (0..4).each do |i|
      letter = @current_guess[i]
      case answer[i]
      when 'y'
        word_matcher.set_found_letter(letter, i)
        @green_letters.push(letter)
      when 'm'
        word_matcher.set_maybe_letter(letter, i)
        @yellow_letters.push(letter)
      end
    end
  end

  # Calculate how many of each letter are possible in the word
  def parse_letter_counts(answer)
    (0..4).each do |i|
      letter = @current_guess[i]
      count = @green_letters.count(letter) + @yellow_letters.count(letter)

      case answer[i]
      when 'n'
        if count.zero?
          word_matcher.set_excluded_letter(letter)
        else
          word_matcher.set_max_letter_count(letter, count)
        end
      else
        word_matcher.set_min_letter_count(letter, count)
      end
    end
  end

  # Look through remaining words and see if there are any letters that exist for every word
  # Given hatch and cards, it should find that A needs to be in second position
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

    return if letter_hash.empty?

    # Found some - add them to known letters!
    letter_hash.each do |i, letter|
      word_matcher.set_found_letter(letter, i)
    end
  end

  # Look over possible guesses, and rates them according to the given distribution
  def rate_words
    @best_word_higher = true
    word_matcher.refresh_regex_pattern
    word_matcher.refresh_found_letters_count
    @positional_ratings = positional_ratings?

    create_distribution

    @possibilities = {}

    @needed_letters = needed_letters

    # Try to rule out remaining letters
    word_list.each do |word|
      @possibilities[word] = rate_word(word)
    end
  end

    # Look over possible guesses, and rates them according to the given distribution
    def rate_words_with_group_size
      @best_word_higher = false

      word_matcher.refresh_regex_pattern
      word_matcher.refresh_found_letters_count
      # @positional_ratings = positional_ratings?

      # create_distribution

      @possibilities = {}

      # @needed_letters = needed_letters

      if @guesses == 0 # first guess
        @possibilities["raise"] = 10 # Sorry!
        return
      end

      # Try to rule out remaining letters
      @possible_answers.each do |word| ## TODO - what if this is word_list?
        @possibilities[word] = find_largest_word_group(word)
      end
    end

  def rate_word(word)
    rating = 0
    seen_letters = []

    word_to_hash(word).each do |index, letter|
      # If not using positional ratings, don't count duplicate letters
      next if !@positional_ratings && seen_letters.include?(letter)

      # If finding unique letters, skip any letter that's known
      if finding_unique_letters?
        next if word_matcher.maybe_letters[index].include?(letter)
        next unless word_matcher.letter_counts[letter][:max].nil?
        next if seen_letters.include?(letter)
      end

      rating += @positional_ratings ? @distribution[index.to_s][letter] : @distribution[letter]
      seen_letters.push(letter)
    end
    rating
  end

  def distribution_by_letter(word)
    word_to_hash(word).each do |index, letter|
      if @positional_ratings
        @distribution[index.to_s][letter] += 1
      else
        next if word_matcher.found_letters[index]

        @distribution[letter] += 1
      end
    end
  end

  ## Given this guess, what's the largest group of words that match the guess?
  def find_largest_word_group(guess)
    answer_groups = {}
    @possible_answers.each do |possible_answer|
      server = Server.new(possible_answer)
      parsed_guess = server.parse_guess(guess)
      answer_groups[parsed_guess] = 0 if answer_groups[parsed_guess].nil? # Initialize this group
      answer_groups[parsed_guess] += 1
    end
    largest_group_size = answer_groups.max_by { |_, count| count }.last
    # puts "Largest group for guess #{guess}: #{answer_groups.max_by { |_, count| count }}" # if debug?
    return largest_group_size
  end


  # Creates a map of how likely letters are to be at a certain position
  # IE, given words cat and cow:
  # c is 2 likely to be at position 0
  def create_distribution
    if finding_unique_letters?
      @distribution = possible_letters
      return
    end

    @distribution = @positional_ratings ? empty_positional_distribution : empty_distribution

    @possible_answers.each do |word|
      next if limit_distribution_to_eligible_words && word_matcher.word_disqualified?(word)

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

  # Date when wordle started
  def start_date
    @zone.local_time(2021, 6, 19, 0, 00, 0)
  end

  def set_word_lists
    @possible_answers = File.read('possible_answers.txt').split
    @ordered_word_list = JSON.parse(File.read('ordered_answers.txt'))
    @guess_word_list = File.read('possible_answers.txt').split
    @guess_word_list.concat(File.read('guess_word_list.txt').split)
    @guess_word_list.uniq!
  end
end
