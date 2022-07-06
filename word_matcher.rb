class WordMatch

  attr_reader :letter_counts, :regex_pattern, :found_letters, :maybe_letters, :found_letters_count

  def initialize(opts = {})
    @options = opts
    @found_letters = @options.key?(:found_letters) ? @options[:found_letters] : [nil, nil, nil, nil, nil]
    @excluded_letters = @options.key?(:excluded_letters) ? @options[:excluded_letters] : []

    @letter_counts = {}
    ('a'..'z').each do |letter|
      @letter_counts[letter] = { 'min': nil, 'max': nil }
    end

    @maybe_letters = [[], [], [], [], []]
  end

  # Sets the minimum count for a letter
  # Check if the value has already been set. If so, select the max value
  # of previous versus massed in count
  def set_min_letter_count(letter, count)
    @letter_counts[letter][:min] = [@letter_counts[letter][:min] ? @letter_counts[letter][:min] : 0, count].max
  end

  def set_found_letter(letter, index)
    @found_letters[index] = letter
  end

  def set_maybe_letter(letter, index)
    @maybe_letters[index] << letter unless @maybe_letters[index].include?(letter)
  end

  def set_excluded_letter(letter)
    @excluded_letters.push(letter) unless @excluded_letters.include?(letter)
  end

  def set_max_letter_count(letter, count)
    @letter_counts[letter][:max] = count
  end

  def refresh_regex_pattern
    regex_pattern = ''
    (0..Wordle::MAX_LENGTH - 1).each do |index|
      regex_pattern << regex_for_index(index)
    end
    @regex_pattern = regex_pattern
  end

  def word_eligible?(word)
    return false unless word.match?(@regex_pattern)
    return false unless contains_included?(word)

    true
  end

  def word_disqualified?(word)
    !word_eligible?(word)
  end

  # How many letters, regardless of position, are found?
  def refresh_found_letters_count
    @found_letters_count = (@letter_counts.reject { |_letter, count_hash| count_hash[:min].nil? }).count
  end

  private

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