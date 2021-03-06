require 'minitest/autorun'
require_relative './wordle'

module TestWordle
  describe Wordle do
    describe 'when asked for a top word' do
      it 'responds with a word' do
        wordle = Wordle.new()
        assert wordle.top_rated_word.length == 5
      end
    end

    describe 'when provided existing guesses' do
      it 'responds with a word' do
        max_counts = {'s' => 0, 'a' => 0, 'i' => 0, 'n' => 0, 't' => 0, 'c' => 0, 'v' => 0}
        min_counts = {'o' => 1, 'e' => 1, 'y' => 1}
        found_letters = [nil, 'o', nil, 'e', nil]

        wordle = Wordle.new({
                                      "debug": true,
                                      "max_counts": max_counts,
                                      "min_counts": min_counts,
                                      "found_letters": found_letters}
        )
        puts wordle.top_rated_word
        assert wordle.top_rated_word == 'foyer'
      end
    end

    describe 'when given a test word' do
      it 'works on single letters' do
        client = Wordle::Server.new('trees')
        response = client.parse_guess('towdy')
        assert response == 'ynnnn'
      end

      it 'finds a maybe match' do
        client = Wordle::Server.new('trees')
        response = client.parse_guess('tordy')
        assert response == 'ynmnn'
      end

      it 'finds duplicate letters' do
        client = Wordle::Server.new('trees')
        response = client.parse_guess('tyeer')
        assert response == 'ynyym'
      end

      it 'works with mixed duplicate letters' do
        client = Wordle::Server.new('trees')
        response = client.parse_guess('teeyy')
        assert response == 'ymynn'
      end

      it 'does not count too many letters' do
        client = Wordle::Server.new('trees')
        response = client.parse_guess('teeee')
        assert response == 'ynyyn'
      end

      it 'suggests correct number of duplicates' do
        client = Wordle::Server.new('trees')
        response = client.parse_guess('eette')
        assert response == 'mmmnn'
      end
    end
  end
end