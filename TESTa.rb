# frozen_string_literal: true

# TEST - Life, the Universe, and Everything
# http://www.spoj.com/problems/TEST/

loop do
  small_number = gets.chomp.to_i
  break if small_number == 42
  puts small_number
end
