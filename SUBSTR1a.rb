require 'open3'

ExecutionResult = Struct.new(:program_text, :input, :output, :status) do
  def join
    puts output
    abort unless status.success?
  end
end

Reference = Struct.new(:type, :name) do
  def to_s
    "#{type}#{name}"
  end
end

Label = Struct.new(:line) do
  def to_s
    "(#{line})"
  end
end

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

  def compile(name)
    output, status = Open3.capture2e("ick -b #{name}.i")
    ExecutionResult.new(program_text, nil, output, status)
  end

  def run(name, input=nil)
    output, status = Open3.capture2e(File.absolute_path(name), stdin_data: input)
    ExecutionResult.new(program_text, input, output, status)
  end
end

module Statements
  def statement(text, label=nil)
    label_text = label.to_s.rjust(3)
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
    statement("#{output} <- #{value}")
  end

  def read(*outputs)
    statement("WRITE IN #{outputs.join(", ")}")
  end

  def write(*values)
    statement("READ OUT #{values.join(", ")}")
  end

  def goto(label)
    statement("#{label} NEXT")
  end

  def exit_program
    statement("GIVE UP")
  end
end

module References
  def initialize_references
    @next_name = 10
  end

  def get_new_name
    result = @next_name
    @next_name += 1
    result
  end

  def define_short(symbol, name=get_new_name)
    define_reference(symbol, Reference.new(".", name))
  end

  def define_short_array(symbol, name=get_new_name)
    define_reference(symbol, Reference.new(",", name))
  end

  def define_reference(symbol, reference)
    getter = symbol
    setter = "#{symbol}=".to_sym
    define_singleton_method(getter) do
      reference
    end
    define_singleton_method(setter) do |value|
      set_value(reference, value)
    end
  end
end

module Expressions
  def literal(value)
    "\##{value}"
  end

  def index(array_reference, value)
    "#{array_reference}SUB#{value}"
  end

  def interleave(x, y)
    "#{x}$#{y}"
  end

  def select(x, y)
    "#{x}~#{y}"
  end

  def group(x)
    "'#{x}'"
  end

  def supergroup(x)
    "\"#{x}\""
  end

  def shift_left_one(x)
    select(
      group(
        interleave(x, literal(0))),
      literal(0b1010_1010_1010_1011))
  end
end

module StandardLibrary
  def initialize_standard_library
    @standard_plus = label(1009)
    @standard_minus = label(1010)

    define_short(:standard_input_1, 1)
    define_short(:standard_input_2, 2)
    define_short(:standard_output_3, 3)
  end

  def set_addition(output, x, y)
    self.standard_input_1 = x
    self.standard_input_2 = y
    goto(@standard_plus)
    set_value(output, standard_output_3)
  end

  def set_subtraction(output, x, y)
    self.standard_input_1 = x
    self.standard_input_2 = y
    goto(@standard_minus)
    set_value(output, standard_output_3)
  end
end

module BinaryIO
  def initialize_binary_io
    define_short(:last_input)
    define_short(:last_output)
    define_short_array(:string_output)
    self.last_input = literal(0)
    self.last_output = literal(0)
    self.string_output = literal(1)
  end

  def read_string(output, length)
    read(output)
    (1..length).each do |i|
      current_char = index(output, literal(i))
      set_addition(
        current_char,
        last_input,
        current_char)
      set_value(
        current_char,
        select(
          group(current_char),
          literal(0xFF))
      )
      self.last_input = current_char
    end
  end

  def parse_string(output, input, length)
    set_value(output, literal(0))
    (1..length).each do |i|
      current_char = index(input, literal(i))
      set_addition(
        output,
        shift_left_one(output),
        select(
          group(current_char),
          literal(0x01)))
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
      index(string_output, literal(1)),
      last_output,
      literal(reversed_value)
    )
    write(string_output)
    self.last_output = literal(reversed_value)
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

class SubstringProgram < Program
  LENGTH_A = 4
  LENGTH_B = 2

  def initialize_local_references
    define_short_array(:string_input_a)
    define_short_array(:string_input_b)
    define_short_array(:string_input_separator)
    define_short(:number_a)
    define_short(:number_b)
  end

  def initialize_arrays
    self.string_input_a = literal(LENGTH_A)
    self.string_input_b = literal(LENGTH_B)
    self.string_input_separator = literal(1)
  end

  def read_separator
    read_string(string_input_separator, 1)
  end

  def read_input
    read_string(string_input_a, LENGTH_A)
    parse_string(number_a, string_input_a, LENGTH_A)
    read_separator
    read_string(string_input_b, LENGTH_B)
    parse_string(number_b, string_input_b, LENGTH_B)
  end

  def compare
    # TODO
  end

  def initialize
    super
    initialize_local_references
    initialize_arrays
    write_string("hello ick world\n")
    #read_input
    #compare
    exit_program
  end
end

def main
  name = "SUBSTR1a"
  program = SubstringProgram.new
  puts program.program_text
  program.write_source(name)
  program.compile(name).join
  program.run(name).join
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
