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
    lines<<"Program:"
    lines<<@program_text
    if !@status.success?
      status_failure_message(lines)
    else
      output_failure_message(lines)
    end
    lines.join("\n")
  end

  def status_failure_message(lines)
    lines<<"Output:"
    lines<<@actual
  end

  def output_failure_message(lines)
    if @input
      lines<<"Input:"
      lines<<@input
    end
    lines<<"Expected output:"
    lines<<expected
    lines<<"Actual output:"
    lines<<@actual
  end

  def diffable?
    @status.success?
  end
end

class TestProgram < Program
  def self.input
    nil
  end

  def self.output_numerals(*numerals)
    numerals
      .map(&method(:convert_numeral))
      .join
  end

  def self.convert_numeral(numeral)
    return "_\n\n" if numeral.zero?
    mapping = %w(IV XL CD)
    i = 0
    text = ""
    loop do
      digit = numeral % 10
      translation =
        case
        when digit <= 3
          mapping[i][0] * digit
        when digit == 4
          "#{mapping[i][0]}#{mapping[i][1]}"
        when digit <= 8
          "#{mapping[i][1]}#{mapping[i][0] * (digit - 5)}"
        else
          "#{mapping[i][0]}#{mapping[i + 1][0]}"
        end
      text = "#{translation}#{text}"
      numeral /= 10
      i += 1
      break if numeral.zero?
    end
    "#{' ' * text.length}\n#{text}\n"
  end
end

def create_program(name, &block)
  program_class = Class.new(TestProgram, &block)
  program_class.define_singleton_method(:name) do
    name
  end
  program_class
end
