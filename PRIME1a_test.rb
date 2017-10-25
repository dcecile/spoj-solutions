require "PRIME1a.rb"

RSpec.describe "Sieve" do
  describe "#remove_multiples" do
    TestCase = Struct.new(
      :name,
      :from,
      :to,
      :prime,
      :result)
    test_cases = [
      TestCase.new(
        "removes all 2s",
        2,
        10,
        2,
        [2, 3, 5, 7, 9]),
      TestCase.new(
        "removes 3s from square",
        2,
        12,
        3,
        [2, 3, 4, 5, 6, 7, 8, 10, 11]),
      TestCase.new(
        "removes from start (exact)",
        12,
        14,
        3,
        [13, 14]),
      TestCase.new(
        "removes from start (before)",
        11,
        14,
        3,
        [11, 13, 14]),
      TestCase.new(
        "removes from start (after)",
        13,
        14,
        3,
        [13, 14]),
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
    TestCase = Struct.new(
      :name,
      :from,
      :to,
      :result)
    test_cases = [
      TestCase.new(
        "finds 2",
        2,
        2,
        [2]),
      TestCase.new(
        "finds first example",
        1,
        10,
        [2, 3, 5, 7]),
      TestCase.new(
        "finds second example",
        3,
        5,
        [3, 5]),
      TestCase.new(
        "finds 10 to 30",
        10,
        30,
        [11, 13, 17, 19, 23, 29]),
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
