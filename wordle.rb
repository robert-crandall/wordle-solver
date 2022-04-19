require 'json'

module Wordle
  class Wordle
    MAX_LENGTH = 5


    def initialize(opts = {})
      @options = opts
      dir = File.dirname(__FILE__)
      @possible_answers = File.read(File.join(dir, 'possible_answers.txt')).split
      @guess_word_list = File.read(File.join(dir, 'possible_answers.txt')).split
      if full_guess_list?
        @guess_word_list.concat(File.read(File.join(dir, 'guess_word_list.txt')).split)
      end
      @exact_counts = {}
      @included_letters = {}
      @maybe_letters = []
      @found_letters = []
      @found = false
      (0..MAX_LENGTH - 1).each do |index|
        @maybe_letters << []
        @found_letters << nil
      end
    end

    def top_rated_word
      rate_words
      @current_guess = (@possibilities.min_by { |k, v| -v })[0]
      @current_guess
    end

    def found?
      @found
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

      if debug?
        puts "Pattern: #{create_regex_pattern}"
        puts "Excluded: #{@exact_counts}"
        puts "Included: #{@included_letters}"
      end
    end

    private

    def full_guess_list?
      @options.has_key?(:full_guess_list)
    end

    def debug?
      @options.has_key?(:full_guess_list)
    end

    def create_regex_pattern
      regex_pattern = ''
      (0..MAX_LENGTH-1).each do |index|
        if @found_letters[index]
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

    # Look over possible guesses, and rates them according to the given distribution
    def rate_words
      distribution = create_distribution
      regex_pattern = create_regex_pattern
      @possibilities = {}

      @guess_word_list.each do |word|
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

    # Creates a map of how likely letters are to be at a certain position
    # IE, given words cat and cow:
    # c is 2 likely to be at position 0
    def create_distribution
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

end
