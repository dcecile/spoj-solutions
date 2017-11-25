require 'open3'

module Listing
  POLITENESS_LEVEL = 5

  def initialize_listing
    @buffer = StringIO.new
    @politeness_counter = 0
  end

  def add_statement(statement)
    @buffer << "#{statement}\n"
    @politeness_counter =
      (@politeness_counter - 1) % POLITENESS_LEVEL
  end

  Label = Struct.new(:line) do
    def compile
      "(#{line})"
    end
  end

  def label(line)
    Label.new(line)
  end

  def politeness_required?
    @politeness_counter == 0
  end

  def program_text
    @buffer.string
  end

  def write_source(name)
    IO.write("#{name}.i", program_text)
  end

  ExecutionResult = Struct.new(:program_text, :input, :output, :status) do
    def join
      puts output
      abort unless status.success?
    end
  end

  def compile(name)
    output, status = Open3.capture2e("ick -b #{name}.i")
    ExecutionResult.new(program_text, nil, output, status)
  end

  def run(name, input=nil)
    output, status = Open3.capture2e(File.absolute_path(name), stdin_data: input)
    ExecutionResult.new(program_text, input, output, status)
  end
end

module Expressions
  module Ops
    def self.define_ops(ops)
      ops.each do |op|
        define_method(op) do |other=nil|
          is_native_self_call = !self.is_a?(Ops) && self.respond_to?(op)
          is_native_other_param = other.nil? || !other.is_a?(Ops)
          if is_native_self_call && is_native_other_param
            self.send(op, *[other].compact)
          else
            OpsImpl.send(op, self, *[other].compact)
          end
        end
      end
    end

    define_ops(%i(
      interleave
      select
      self_and
      self_or
      self_xor
      <<
      >>
      &
      |
      ^
      !
      ==
      !=
    ))
  end

  module Literal
    include Ops

    def compile(group)
      "\##{self}"
    end
  end

  module Refinements
    refine Integer do
      include Literal
    end
  end

  using Refinements

  class Primitive
    include Ops

    def self.new_binary(operator, x, y)
      new do |group|
        group.compile([group.next(x), operator, group.next(y)].join)
      end
    end

    def self.new_unary(operator, x)
      new do |group|
        group.compile([operator, group.next(x)].join)
      end
    end

    def initialize(&compile_block)
      @compile_block = compile_block
    end

    def compile(group)
      @compile_block.call(group)
    end
  end

  class Group
    def initialize(text, next_group)
      @text = text
      @next_group = next_group
    end

    def compile(inner)
      [@text, inner, @text].join
    end

    def next(inner)
      inner.compile(Group.const_get(@next_group))
    end

    def self.compile(inner)
      inner.compile(ZERO)
    end

    ZERO = new("", :ONE)
    ONE = new("'", :TWO)
    TWO = new('"', :ONE)
  end

  module OpsImpl
    def self.interleave(x, y)
      Primitive.new_binary("$", x, y)
    end

    def self.select(x, y)
      Primitive.new_binary("~", x, y)
    end

    def self.self_and(x)
      Primitive.new_unary("&", x)
    end

    def self.self_or(x)
      Primitive.new_unary("V", x)
    end

    def self.self_xor(x)
      Primitive.new_unary("?", x)
    end

    def self.<<(x, y)
      result = x
      y.times do
        result = result
          .interleave(0)
          .select(0b1010_1010_1010_1011)
      end
      result
    end

    def self.>>(x, y)
      x.select((0xFFFF << y) & 0xFFFF)
    end

    def self.bitwise(x, y, unary_op)
      x.interleave(y).send(unary_op).select(0.interleave(0xFFFF))
    end

    def self.&(x, y)
      bitwise(x, y, :self_and)
    end

    def self.|(x, y)
      bitwise(x, y, :self_or)
    end

    def self.^(x, y)
      bitwise(x, y, :self_xor)
    end

    def self.!(x)
      x ^ 1
    end

    def self.==(x, y)
      !(x != y)
    end

    def self.!=(x, y)
      0xFFFF.select(x ^ y).select(1)
    end
  end
end

module Statements
  include Expressions

  def statement(text, label=nil)
    label_text = label&.compile&.rjust(3)
    command_text =
      if politeness_required?
        "PLEASE"
      else
        "DO"
      end
    statement = "#{label_text} #{command_text} #{text}"
    add_statement(statement)
  end

  def set_value(output, value)
    statement("#{Group.compile(output)} <- #{Group.compile(value)}")
  end

  def read(output)
    statement("WRITE IN #{Group.compile(output)}")
  end

  def write(value)
    statement("READ OUT #{Group.compile(value)}")
  end

  def goto(label)
    statement("#{label.compile} NEXT")
  end

  def exit_program
    statement("GIVE UP")
  end
end

module References
  include Expressions

  def initialize_references
    @next_name = 10
  end

  Reference = Struct.new(:program, :type, :name) do
    include Ops

    def compile(group)
      "#{type}#{name}"
    end

    def value=(value)
      program.set_value(self, value)
    end

    def [](index)
      IndexReference.new(self, index)
    end
  end

  IndexReference = Struct.new(:reference, :index) do
    include Ops

    def compile(group)
      group.compile("#{group.next(reference)}SUB#{group.next(index)}")
    end

    def value=(value)
      reference.program.set_value(self, value)
    end
  end

  def make_short(name: get_new_name, value: nil)
    reference = Reference.new(self, ".", name)
    reference.value = value if value
    reference
  end

  def make_short_array(name: get_new_name, value: nil)
    reference = Reference.new(self, ",", name)
    reference.value = value if value
    reference
  end

  def get_new_name
    result = @next_name
    @next_name += 1
    result
  end
end

module StandardLibrary
  def initialize_standard_library
    @standard_plus = label(1009)
    @standard_minus = label(1010)
    @standard_input_1 = make_short(name: 1)
    @standard_input_2 = make_short(name: 2)
    @standard_output_3 = make_short(name: 3)
  end

  def set_addition(output, x, y)
    @standard_input_1.value = x
    @standard_input_2.value = y
    goto(@standard_plus)
    output.value = @standard_output_3
  end

  def set_subtraction(output, x, y)
    @standard_input_1.value = x
    @standard_input_2.value = y
    goto(@standard_minus)
    output.value = @standard_output_3
  end
end

module BinaryIO
  def initialize_binary_io
    @last_input = make_short(value: 0)
    @last_output = make_short(value: 0)
    @string_output = make_short_array(value: 1)
  end

  def read_string(output, length)
    read(output)
    (1..length).each do |i|
      set_addition(output[i], @last_input, output[i])
      output[i].value = output[i] & 0xFF
      @last_input.value = output[i]
    end
  end

  def parse_string(output, input, length)
    output.value = 0
    (1..length).each do |i|
      output.value = (output << 1) | (input[i] & 1)
    end
  end

  def reverse_bits(value)
    value = ((value & 0b00001111) << 4) | ((value & 0b11110000) >> 4)
    value = ((value & 0b00110011) << 2) | ((value & 0b11001100) >> 2)
    value = ((value & 0b01010101) << 1) | ((value & 0b10101010) >> 1)
    value
  end

  def write_char(char)
    value = char.codepoints.first
    reversed_value = reverse_bits(value)
    set_subtraction(
      @string_output[1],
      @last_output,
      reversed_value
    )
    write(@string_output)
    @last_output.value = reversed_value
  end

  def write_string(string)
    string.chars.each do |char|
      write_char(char)
    end
  end
end

class Program
  include Listing
  include Statements
  include References
  include Expressions
  include StandardLibrary
  include BinaryIO

  def initialize
    initialize_listing
    initialize_references
    initialize_standard_library
    initialize_binary_io
  end
end

module SubstringSolution
  LENGTH_A = 4
  LENGTH_B = 2

  def initialize_solution
    @string_input_a = make_short_array(value: LENGTH_A)
    @string_input_b = make_short_array(value: LENGTH_A)
    @string_input_separator = make_short_array(value: 1)
    @number_a = make_short
    @number_b = make_short
  end

  def read_separator
    read_string(@string_input_separator, 1)
  end

  def read_input
    read_string(@string_input_a, LENGTH_A)
    parse_string(@number_a, @string_input_a, LENGTH_A)
    read_separator
    read_string(@string_input_b, LENGTH_B)
    parse_string(@number_b, @string_input_b, LENGTH_B)
  end

  def run_solution
    initialize_solution
    read_input
    write(@number_a)
    write(@number_b)
    exit_program
  end
end

def main
  name = "SUBSTR1a"
  program = Program.new
  program.extend(SubstringSolution)
  program.run_solution
  puts program.program_text
  program.write_source(name)
  program.compile(name).join
end

if __FILE__ == $PROGRAM_NAME
  main
end

# Ideal setup:
# - define x= methods for variables
# - set up + ~ ... operators for expressions
# - use automatic grouping

# Set up a variable with 1 or 2
# Jump from if to else, to test
# Return to 1 or 2
#      DO WRITE IN :1
#      DO (02) NEXT
# (01) DO READ OUT #3
#      DO (04) NEXT
# (02) DO (03) NEXT
#      DO FORGET #1
#      DO READ OUT #5
#      DO (04) NEXT
# (03) PLEASE RESUME :1
# (04) PLEASE FORGET #1
#      PLEASE GIVE UP
