# frozen_string_literal: true

require "PRIME1a"

RSpec.describe "Sieve" do
  describe "#remove_multiples" do
    RemoveMultiplesTestCase = Struct.new(
      :name,
      :from,
      :to,
      :prime,
      :result
    )
    test_cases = [
      RemoveMultiplesTestCase.new(
        "removes all 2s",
        2,
        10,
        2,
        [2, 3, 5, 7, 9]
      ),
      RemoveMultiplesTestCase.new(
        "removes 3s from square",
        2,
        12,
        3,
        [2, 3, 4, 5, 6, 7, 8, 10, 11]
      ),
      RemoveMultiplesTestCase.new(
        "removes from start (exact)",
        12,
        14,
        3,
        [13, 14]
      ),
      RemoveMultiplesTestCase.new(
        "removes from start (before)",
        11,
        14,
        3,
        [11, 13, 14]
      ),
      RemoveMultiplesTestCase.new(
        "removes from start (after)",
        13,
        14,
        3,
        [13, 14]
      )
    ]
    test_cases.each do |test_case|
      it test_case.name do
        sieve = Sieve.new(test_case.from, test_case.to)
        sieve.remove_multiples(test_case.prime)
        actual_result = []
        sieve.each_prime do |prime|
          actual_result << prime
        end
        expect(actual_result).to eq(test_case.result)
      end
    end
  end

  describe ".find_each_prime" do
    FindEachTestCase = Struct.new(
      :name,
      :from,
      :to,
      :result
    )
    test_cases = [
      FindEachTestCase.new(
        "finds 2",
        2,
        2,
        [2]
      ),
      FindEachTestCase.new(
        "finds first example",
        1,
        10,
        [2, 3, 5, 7]
      ),
      FindEachTestCase.new(
        "finds second example",
        3,
        5,
        [3, 5]
      ),
      FindEachTestCase.new(
        "finds 10 to 30",
        10,
        30,
        [11, 13, 17, 19, 23, 29]
      )
    ]
    test_cases.each do |test_case|
      it test_case.name do
        actual_result = []
        Sieve.find_each_prime(test_case.from, test_case.to) do |prime|
          actual_result << prime
        end
        expect(actual_result).to eq(test_case.result)
      end
    end
  end
end
