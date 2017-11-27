# frozen_string_literal: true

# SBSTR1 - Substring Check (Bug Funny)
# http://www.spoj.com/problems/SBSTR1/

require "open3"

# Listing contains all program source text, and
# can compile & run the program
module Listing
  POLITENESS_LEVEL = 5

  def initialize_listing
    @buffer = StringIO.new
    @politeness_counter = 0
    @next_label_name = 1
  end

  def add_statement(statement)
    @buffer << "#{statement}\n"
    @politeness_counter =
      (@politeness_counter - 1) % POLITENESS_LEVEL
  end

  Label = Struct.new(:name) do
    def compile
      "(#{name})"
    end
  end

  def make_label(name: new_label_name)
    Label.new(name)
  end

  def make_labels(count)
    Array.new(count).map { make_label }
  end

  def new_label_name
    result = @next_label_name
    @next_label_name += 1
    result
  end

  def politeness_required?
    @politeness_counter.zero?
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

  def run(name, input)
    output, status = Open3.capture2e(
      File.absolute_path(name),
      stdin_data: input
    )
    ExecutionResult.new(program_text, input, output, status)
  end
end

# Expressions includes all native Intercal operations,
# helper bitwise methods, and Ruby Integer refinements
module Expressions
  # Ops is a mixin for all Intercal expressions
  module Ops
    def self.define_ops(ops)
      ops.each do |op|
        define_method(op) do |other = nil|
          Ops.call_op(op, self, other)
        end
      end
    end

    def self.call_op(op, x, y)
      is_native_x_call = !x.is_a?(Ops) && x.respond_to?(op)
      is_native_y_param = y.nil? || !y.is_a?(Ops)
      if is_native_x_call && is_native_y_param
        x.send(op, *[y].compact)
      else
        OpsImpl.send(op, x, *[y].compact)
      end
    end

    define_ops(
      %i[
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
      ]
    )
  end

  # Literal is a mixin for Ruby Integer refinments
  module Literal
    include Ops

    def compile(_group)
      "\##{self}"
    end
  end

  # Refinements refines Ruby's Integer class to support
  # compilation to an Intercal expression and all Intercal
  # operations
  module Refinements
    refine Integer do
      include Literal
    end
  end

  using Refinements

  # Primitive is a basic binary or unary operator supported
  # natively in the Intercal language
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

  # Group is required to support nested expressions in Intercal,
  # and all grouped output is handled automatically by this class
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

  # OpsImpl implements all primitive and supplementary
  # methods for Intercal expressions
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
        result =
          result
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
      # rubocop:disable Style/InverseMethods
      # Implement equality in terms of inequality
      !(x != y)
      # rubocop:enable Style/InverseMethods
    end

    def self.!=(x, y)
      0xFFFF.select(x ^ y).select(1)
    end
  end
end

# Statements includes definitions for basic Intercal
# statements: set value, read, write, jump, exit
module Statements
  include Expressions

  NOP_TEXT = "DON'T GIVE UP"

  def statement(text, label = nil)
    label_text = (label&.compile || "").rjust(4)
    command_text = adjust_statement_text(text)
    statement = "#{label_text} #{command_text}"
    add_statement(statement)
  end

  def adjust_statement_text(text)
    if politeness_required?
      "PLEASE #{text}"
    elsif text == NOP_TEXT
      text
    else
      "DO #{text}"
    end
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

  def label_nop(label)
    statement(NOP_TEXT, label)
  end

  def jump_and_push_stack(label)
    statement("#{label.compile} NEXT")
  end

  def pop_stack_and_jump(count)
    statement("RESUME #{Group.compile(count)}")
  end

  def pop_stack_and_discard(count)
    statement("FORGET #{Group.compile(count)}")
  end

  def exit_program
    statement("GIVE UP")
  end
end

# ControlFlow includes structural programming concepts
module ControlFlow
  include Expressions

  def if_else_block(condition, if_lambda, else_lambda)
    IfElseBlock.new(self, condition, if_lambda, else_lambda).compile
  end

  # IfElseBlock is a structured if-else block
  class IfElseBlock
    def initialize(program, condition, if_lambda, else_lambda)
      @program = program
      @condition = condition
      @if_lambda = if_lambda
      @else_lambda = else_lambda
      @else_label, @condition_label, @end_label = @program.make_labels(3)
    end

    def compile
      compile_if
      compile_else
      compile_condition
      compile_end
    end

    def compile_if
      @program.jump_and_push_stack(@else_label)
      @if_lambda.call
      @program.jump_and_push_stack(@end_label)
    end

    def compile_else
      @program.label_nop(@else_label)
      @program.jump_and_push_stack(@condition_label)
      @program.pop_stack_and_discard(1)
      @else_lambda.call
      @program.jump_and_push_stack(@end_label)
    end

    def compile_condition
      @program.label_nop(@condition_label)
      @program.pop_stack_and_discard(@condition)
      @program.pop_stack_and_jump(1)
    end

    def compile_end
      @program.label_nop(@end_label)
      @program.pop_stack_and_discard(1)
    end
  end

  def while_block(condition, &body_block)
    WhileBlock.new(self, condition, body_block).compile
  end

  # WhileBlock is a structured while block
  class WhileBlock
    def initialize(program, condition, body_block)
      @program = program
      @condition = condition
      @body_block = body_block
      @body_label, @condition_label, @end_label = @program.make_labels(3)
    end

    def compile
      compile_begin
      compile_body
      compile_condition
      compile_end
    end

    def compile_begin
      @program.jump_and_push_stack(@body_label)
      @program.jump_and_push_stack(@end_label)
    end

    def compile_body
      @program.label_nop(@body_label)
      @program.jump_and_push_stack(@condition_label)
      @program.pop_stack_and_discard(1)
      @body_block.call
      compile_begin
    end

    def compile_condition
      @program.label_nop(@condition_label)
      @program.pop_stack_and_discard(!@condition)
      @program.pop_stack_and_jump(1)
    end

    def compile_end
      @program.label_nop(@end_label)
      @program.pop_stack_and_discard(1)
    end
  end
end

# References includes Intercal short integer and short
# integer array variable references
module References
  include Expressions

  def initialize_references
    @next_reference_name = 10
  end

  Reference = Struct.new(:program, :type, :name) do
    include Ops

    def compile(_group)
      "#{type}#{name}"
    end

    def value
      self
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

    def value
      self
    end

    def value=(value)
      reference.program.set_value(self, value)
    end
  end

  def make_short(name: new_reference_name, value: nil)
    reference = Reference.new(self, ".", name)
    reference.value = value if value
    reference
  end

  def make_short_array(name: new_reference_name, value: nil)
    reference = Reference.new(self, ",", name)
    reference.value = value if value
    reference
  end

  def new_reference_name
    result = @next_reference_name
    @next_reference_name += 1
    result
  end
end

# StandardLibrary provides a limited interface to the Intercal
# standard library (addition, subtraction)
module StandardLibrary
  def initialize_standard_library
    @standard_plus = make_label(name: 1009)
    @standard_minus = make_label(name: 1010)
    @standard_input1 = make_short(name: 1)
    @standard_input2 = make_short(name: 2)
    @standard_output3 = make_short(name: 3)
  end

  def set_addition(output, x, y)
    @standard_input1.value = x
    @standard_input2.value = y
    jump_and_push_stack(@standard_plus)
    output.value = @standard_output3
  end

  def set_subtraction(output, x, y)
    @standard_input1.value = x
    @standard_input2.value = y
    jump_and_push_stack(@standard_minus)
    output.value = @standard_output3
  end
end

# BinaryIO includes the C-INTERCAL API for reading
# and writing binary data
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
      output[i].value &= 0xFF
      @last_input.value = output[i]
    end
  end

  def parse_string(output, input, length)
    output.value = 0
    (1..length).each do |i|
      output.value = (output << 1) | (input[i] & 1)
    end
  end

  # rubocop:disable Metrics/AbcSize
  def reverse_bits(value)
    # TODO: Find out why this code is in violation and if it needs fixing
    value = ((value & 0b00001111) << 4) | ((value & 0b11110000) >> 4)
    value = ((value & 0b00110011) << 2) | ((value & 0b11001100) >> 2)
    value = ((value & 0b01010101) << 1) | ((value & 0b10101010) >> 1)
    value
  end
  # rubocop:enable Metrics/AbcSize

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

# Program includes all modules needed for general Intercal
# programs
class Program
  include Listing
  include Statements
  include ControlFlow
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

# SubstringSolution includes an implementation for the
# SPOJ SUBSTR1 solution
module SubstringSolution
  LENGTH_A = 4
  LENGTH_B = 2
  DEFAULT_MASK = (1 << LENGTH_B) - 1

  def initialize_solution
    @string_input_a = make_short_array(value: LENGTH_A)
    @string_input_b = make_short_array(value: LENGTH_B)
    @string_input_separator = make_short_array(value: 1)
    @loop_counter = make_short
    @number_a = make_short
    @number_b = make_short
    @is_substring = make_short
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
    read_separator
  end

  def check_for_substring_match
    @is_substring.value = 0
    (0..(LENGTH_A - LENGTH_B)).each do |i|
      @is_substring.value |= check_substring(i)
    end
    if_else_block(
      @is_substring,
      -> { write_string("1\n") },
      -> { write_string("0\n") }
    )
  end

  def check_substring(i)
    @number_a.select(DEFAULT_MASK << i) == @number_b
  end

  def run_solution(problem_count)
    initialize_solution
    @loop_counter.value = 0
    while_block(@loop_counter != problem_count) do
      read_input
      check_for_substring_match
      set_addition(@loop_counter, @loop_counter, 1)
    end
    exit_program
  end
end

def main
  name = "SUBSTR1a"
  program = Program.new
  program.extend(SubstringSolution)
  program.run_solution(24)
  puts program.program_text
  program.write_source(name)
  program.compile(name).join
end

main if $PROGRAM_NAME == __FILE__
