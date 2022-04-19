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
        remove_word_from_guesses
        return
      end

      if answer == 'yyyyy'
        puts 'Congrats!! Found the word!!' unless quiet?
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
          @exact_counts[@current_guess[i]] = if @included_letters.key?(@current_guess[i])
            @included_letters[@current_guess[i]]
          else
            0
                                             end
        end
        i += 1
      end

      return unless debug?

      puts "Pattern: #{create_regex_pattern}"
      puts "Excluded: #{@exact_counts}"
      puts "Included: #{@included_letters}"
    end

    private

    def full_guess_list?
      @options.key?(:full_guess_list)
    end

    # How many times to use full word list until switching to answers only list?
    # Improvement at 1 for small list, bad for large list
    # TODO - retest after changing dupes and limits
    def full_guess_list_until
      0
    end

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

    def quiet?
      @options.key?(:quiet)
    end

    def debug?
      @options.key?(:debug)
    end

    def create_word_arrays
      @exact_counts = @options.key?(:exact_counts) ? @options[:exact_counts] : {}

      @included_letters = @options.key?(:included_letters) ? @options[:included_letters] : {}
      @found_letters = @options.key?(:found_letters) ? @options[:found_letters] : [nil, nil, nil, nil, nil]

      @maybe_letters = [[], [], [], [], []]
    end

    def create_regex_pattern
      regex_pattern = ''
      (0..MAX_LENGTH - 1).each do |index|
        regex_pattern << if @found_letters[index]
          @found_letters[index]
        elsif !@maybe_letters[index].empty?
          "[^#{@maybe_letters[index].join('')}]"
        else
          '[a-z]'
        end
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
      distribution = create_distribution

      @possibilities = {}

      word_list = @possible_answers
      word_list = @possible_answers + @guess_word_list if guesses < full_guess_list_until

      word_list.each do |word|
        rating = 0
        next unless eligible?(word)

        if count_dupes_by_position
          char_occurance = {}
          word_to_hash(word).each do |index, letter|
            if count_dupes_by_position
              if char_occurance.key?(letter)
                char_occurance[letter] += 1
              else
                char_occurance[letter] = 0
              end
              occurance = char_occurance[letter]
              rating += distribution[index.to_s][letter][occurance]
            end
          end
        end

        # Easier to remove when necessary
        unless count_dupes_by_position
          word_to_hash(word).each do |index, letter|
            rating += distribution[index.to_s][letter]
          end
        end

        @possibilities[word] = rating
      end
    end

    # Creates a map of how likely letters are to be at a certain position
    # IE, given words cat and cow:
    # c is 2 likely to be at position 0
    def create_distribution
      positional_distribution = empty_positional_distribution

      @possible_answers.each do |word|
        next if limit_distribution_to_eligible_words && !eligible?(word)

        char_occurance = {}
        word_to_hash(word).each do |index, letter|
          if count_dupes_by_position
            if char_occurance.key?(letter)
              char_occurance[letter] += 1
            else
              char_occurance[letter] = 0
            end
            occurance = char_occurance[letter]
            positional_distribution[index.to_s][letter][occurance] += 1
          else
            positional_distribution[index.to_s][letter] += 1
          end
        end
      end
      positional_distribution
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
      @exact_counts.each do |letter, count|
        return true if word.count(letter) > count
      end
      false
    end

    # Does the given word include all the included letters?
    def contains_included?(word)
      @included_letters.each do |letter, count|
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
