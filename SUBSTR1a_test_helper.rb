# frozen_string_literal: true

require "rspec/expectations"
require "SUBSTR1a"

RSpec::Matchers.define :succeed_and_output do |expected|
  match do |actual|
    @program_text = actual.program_text
    @input = actual.input
    @actual = actual.output
    @status = actual.status
    if !@status.success?
      false
    else
      values_match?(@actual, expected)
    end
  end

  failure_message do
    lines = []
    lines << "Program:"
    lines << @program_text
    if !@status.success?
      status_failure_message(lines)
    else
      output_failure_message(lines)
    end
    lines.join("\n")
  end

  def status_failure_message(lines)
    lines << "Output:"
    lines << @actual
  end

  def output_failure_message(lines)
    if @input
      lines << "Input:"
      lines << @input
    end
    lines << "Expected output:"
    lines << expected
    lines << "Actual output:"
    lines << @actual
  end

  def diffable?
    @status.success?
  end
end

# A special Intercal program for writing tests, with
# self-contained test input and test output
class TestProgram < Program
  def self.input
    nil
  end

  def self.input_problems(problems)
    problems
      .map do |problem|
        number_a = problem[0].to_s(2).rjust(SubstringSolution::LENGTH_A, "0")
        number_b = problem[1].to_s(2).rjust(SubstringSolution::LENGTH_B, "0")
        [number_a, number_b].join(" ")
      end
      .join("\n")
  end

  def self.output_numerals(*numerals)
    numerals
      .map(&method(:convert_numeral))
      .join
  end

  def self.convert_numeral(numeral)
    return "_\n\n" if numeral.zero?
    translations =
      split_digits(numeral)
      .each_with_index
      .map(&method(:translate_numeral_digit))
    text = translations.reverse.join
    "#{' ' * text.length}\n#{text}\n"
  end

  def self.split_digits(numeral)
    Enumerator.new do |yielder|
      loop do
        yielder << (numeral % 10)
        numeral /= 10
        break if numeral.zero?
      end
    end
  end

  NUMERALS = %w[IV XL CD ??].freeze
  NUMERAL_SEQUENCE = [
    "",
    "I",
    "II",
    "III",
    "IV",
    "V",
    "VI",
    "VII",
    "VIII",
    "IX"
  ].freeze

  def self.translate_numeral_digit(digit_value, digit_index)
    NUMERAL_SEQUENCE[digit_value]
      .gsub("X", NUMERALS[digit_index + 1][0])
      .gsub("V", NUMERALS[digit_index][1])
      .gsub("I", NUMERALS[digit_index][0])
  end
end

def create_program(name, &block)
  program_class = Class.new(TestProgram, &block)
  program_class.define_singleton_method(:name) do
    name
  end
  program_class
end
