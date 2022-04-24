require 'minitest/autorun'
require_relative './server'

module TestWordle
  describe Server do

    describe 'when given a test word' do
      it 'works on single letters' do
        client = Server.new('trees')
        response = client.parse_guess('towdy')
        assert response == 'ynnnn'
      end

      it 'finds a maybe match' do
        client = Server.new('trees')
        response = client.parse_guess('tordy')
        assert response == 'ynmnn'
      end

      it 'finds duplicate letters' do
        client = Server.new('trees')
        response = client.parse_guess('tyeer')
        assert response == 'ynyym'
      end

      it 'works with mixed duplicate letters' do
        client = Server.new('trees')
        response = client.parse_guess('teeyy')
        assert response == 'ymynn'
      end

      it 'does not count too many letters' do
        client = Server.new('trees')
        response = client.parse_guess('teeee')
        assert response == 'ynyyn'
      end

      it 'suggests correct number of duplicates' do
        client = Server.new('trees')
        response = client.parse_guess('eette')
        assert response == 'mmmnn'
      end
    end
  end
end