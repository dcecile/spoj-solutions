# PRIME1 - Prime Generator
# http://www.spoj.com/problems/PRIME1/

# Use two sieves in combination: one to find all
# possible "factor" primes, and one to find all
# primes in the target range
class Sieve
  def self.find_each_prime(from, to, &block)
    seed = Sieve.new(2, Math.sqrt(to).floor)
    output = Sieve.new([from, 2].max, to)
    seed.each_prime do |prime|
      seed.remove_multiples(prime)
      output.remove_multiples(prime)
    end
    output.each_prime(&block)
  end

  def initialize(from, to)
    @from = from
    @to = to
    @is_prime = Array.new(@to - @from + 1, true)
  end

  def remove_multiples(prime)
    multiple = prime * prime
    multiple = prime * (@from / prime.to_f).ceil if multiple < @from
    while multiple <= @to
      invalidate_prime(multiple)
      multiple += prime
    end
  end

  def each_prime
    (@from..@to).each do |n|
      yield n if prime?(n)
    end
  end

  def invalidate_prime(n)
    @is_prime[n - @from] = false
  end

  def prime?(n)
    @is_prime[n - @from]
  end
end

def main
  test_cases_count = gets.chomp.to_i
  (1..test_cases_count).each do
    from, to = gets.chomp.split.map(&:to_i)
    Sieve.find_each_prime(from, to) do |prime|
      puts prime
    end
    puts
  end
end

main if $PROGRAM_NAME == __FILE__
