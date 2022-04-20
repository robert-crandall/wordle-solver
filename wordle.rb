require 'json'

module Wordle
  class Wordle
    MAX_LENGTH = 5

    def initialize(opts = {})
      @options = opts
      dir = File.dirname(__FILE__)
      @possible_answers = File.read(File.join(dir, 'possible_answers.txt')).split
      @guess_word_list = File.read(File.join(dir, 'guess_word_list.txt')).split
      @guesses = 0
      @found = false
      create_word_arrays
    end

    def top_rated_word
      rate_words
      @guesses += 1
      @current_guess = (@possibilities.min_by { |k, v| -v })[0]
      @current_guess
    end

    def found?
      @found
    end

    def guesses
      @guesses
    end

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
      (0..4).each do |i|
        letter = @current_guess[i]
        case answer[i]
        when 'n'
          @max_counts[letter] = green_letters.count(letter) + yellow_letters.count(letter)
        when 'm'
          @min_counts[letter] = green_letters.count(letter) + yellow_letters.count(letter)
        when 'y'
          @min_counts[letter] = green_letters.count(letter) + yellow_letters.count(letter)
        end
      end

      return unless debug?

      puts "Pattern: #{create_regex_pattern}"
      puts "Max Counts: #{@max_counts}"
      puts "Min Counts: #{@min_counts}"
    end

    private

    # Use positional logic for treating dupes
    # When false:
    # Small moved from 10 to 4 failures
    # Full moved from 19 to 17 failures
    def count_dupes_by_position
      false
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
      found_letters = @min_counts.values.sum
      guesses < 2 && found_letters < 5
    end

    def quiet?
      @options.key?(:quiet)
    end

    def debug?
      @options.key?(:debug)
    end

    def create_word_arrays
      @max_counts = @options.key?(:max_counts) ? @options[:max_counts] : {}

      @min_counts = @options.key?(:min_counts) ? @options[:min_counts] : {}
      @found_letters = @options.key?(:found_letters) ? @options[:found_letters] : [nil, nil, nil, nil, nil]

      @maybe_letters = [[], [], [], [], []]
    end

    def regex_for_index(index)
      if @found_letters[index]
        @found_letters[index]
      elsif !@maybe_letters[index].empty?
        "[^#{@maybe_letters[index].join('')}]"
      else
        '[a-z]'
      end
    end

    def create_regex_pattern
      regex_pattern = ''
      (0..MAX_LENGTH - 1).each do |index|
        regex_pattern << regex_for_index(index)
      end
      regex_pattern
    end

    def eligible?(word)
      regex_pattern = create_regex_pattern

      return false unless word.match?(regex_pattern)
      return false if contains_excluded?(word)
      return false unless contains_included?(word)

      true
    end

    # Look over possible guesses, and rates them according to the given distribution
    def rate_words
      create_distribution

      @possibilities = {}

      word_list = @possible_answers

      word_list.each do |word|
        unless maximize_unknown_letters?
          next unless eligible?(word)
        end

        @possibilities[word] = count_dupes_by_position ? rate_word_by_positional_dupes(word) : rate_word(word)
      end
    end

    def rate_word_by_positional_dupes(word)
      rating = 0
      char_occurence = {}
      word_to_hash(word).each do |index, letter|
        if char_occurence.key?(letter)
          char_occurence[letter] += 1
        else
          char_occurence[letter] = 0
        end
        occurance = char_occurence[letter]
        rating += @positional_distribution[index.to_s][letter][occurance]
      end
      rating
    end

    def rate_word(word)
      rating = 0
      seen_letters = []

      word_to_hash(word).each do |index, letter|
        rating += @positional_distribution[index.to_s][letter]
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

    def distribution_by_letter(word)
      word_to_hash(word).each do |index, letter|
        @positional_distribution[index.to_s][letter] += 1
      end
    end

    # Creates a map of how likely letters are to be at a certain position
    # IE, given words cat and cow:
    # c is 2 likely to be at position 0
    def create_distribution
      @positional_distribution = empty_positional_distribution

      word_list = @possible_answers # Having this be full word list saw more failures

      word_list.each do |word|
        next if limit_distribution_to_eligible_words && !eligible?(word)

        count_dupes_by_position ? distribution_by_positional_duplicates(word) : distribution_by_letter(word)
      end
    end

    # Holds letters and counts of those letters
    def empty_distribution
      distribution = {}
      ('a'..'z').each do |letter|
        distribution[letter] = count_dupes_by_position ? [0, 0, 0, 0, 0] : 0
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
      return true if @max_counts.key?(letter)
      return true if @min_counts.key?(letter)

      false
    end

    # Does the given word include all the included letters?
    def contains_included?(word)
      @min_counts.each do |letter, count|
        return false if word.count(letter) < count
        # return false unless word.include?(letter)
      end
      true
    end
  end

  class Server
    def initialize(word)
      @answer = word
    end

    def answer
      @answer
    end

    def parse_guess(guess_str)
      response = %w[n n n n n]
      guess = guess_str.split('')
      answer = @answer.split('')
      green_letters = []
      yellow_letters = []

      (0..4).each do |i|
        if answer[i] == guess[i]
          response[i] = 'y'
          green_letters.push(guess[i])
        end
      end

      (0..4).each do |i|
        letter = guess[i]
        answer_count = answer.count(letter)
        found_count = green_letters.count(letter) + yellow_letters.count(letter)
        if answer_count > found_count && (response[i] != 'y')
            response[i] = 'm'
            yellow_letters.push(letter)
          end
      end
      response.join('')
    end
  end
end
