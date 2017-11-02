require 'singleton'
require 'open3'

ExecutionResult = Struct.new(:program_text, :input, :output, :status)

class Program
  include Singleton

  POLITENESS_LEVEL = 5

  def initialize
    @next_name = 10
    @buffer = StringIO.new
    @politeness_counter = 0
  end

  def add_statement(statement)
    @buffer << "#{statement}\n"
    @politeness_counter =
      (@politeness_counter - 1) % POLITENESS_LEVEL
  end

  def get_new_name
    result = @next_name
    @next_name += 1
    result
  end

  def politeness_required?
    @politeness_counter == 0
  end

  def program_text
    @buffer.string
  end

  def write(name)
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

Reference = Struct.new(:type, :name) do
  def to_s
    "#{type}#{name}"
  end
end

def short_reference(name=get_new_name)
  Reference.new(".", name)
end

def long_reference(name=get_new_name)
  Reference.new(":", name)
end

def short_array_reference(name=get_new_name)
  Reference.new(",", name)
end

def long_array_reference(name=get_new_name)
  Reference.new(";", name)
end

Label = Struct.new(:line) do
  def to_s
    "(#{line})"
  end
end

def label(line)
  Label.new(line)
end

# Expressions
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
      interleave(x, literal(0)),
    literal(0x1010_1010_1010_1011)))
end

# Output

def get_new_name
  Program.instance.get_new_name
end

def execute_program(name)
  Program.instance.write(name)
  Program.instance.compile(name)
  Program.instance.run(name)
end

# Standard library

STANDARD_PLUS = label(1009)
STANDARD_MINUS = label(1010)

STANDARD_INPUT_1 = short_reference(1)
STANDARD_INPUT_2 = short_reference(2)
STANDARD_OUTPUT_3 = short_reference(3)

# Statements

def statement(text, label=nil)
  label_text = label.to_s.rjust(3)
  command_text =
    if Program.instance.politeness_required?
      "PLEASE"
    else
      "DO"
    end
  statement = "#{label_text} #{command_text} #{text}"
  Program.instance.add_statement(statement)
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

def set_addition(output, x, y)
  set_value(STANDARD_INPUT_1, x)
  set_value(STANDARD_INPUT_2, y)
  goto(STANDARD_PLUS)
  set_value(output, STANDARD_OUTPUT_3)
end

def set_subtraction(output, x, y)
  set_value(STANDARD_INPUT_1, x)
  set_value(STANDARD_INPUT_2, y)
  goto(STANDARD_MINUS)
  set_value(output, STANDARD_OUTPUT_3)
end

def exit_program
  statement("GIVE UP")
end

# Program
LENGTH_A = 4
LENGTH_B = 2
STRING_INPUT_A = short_array_reference()
STRING_INPUT_B = short_array_reference()
STRING_INPUT_SEPARATOR = short_array_reference()
STRING_OUTPUT = short_array_reference()
LAST_INPUT = short_reference()
LAST_OUTPUT = short_reference()
NUMBER_A = short_reference()
NUMBER_B = short_reference()

def initialize_arrays
  set_value(STRING_INPUT_A, literal(LENGTH_A))
  set_value(STRING_INPUT_B, literal(LENGTH_B))
  set_value(STRING_INPUT_SEPARATOR, literal(1))
  set_value(STRING_OUTPUT, literal(1))
end

def initialize_globals
  set_value(LAST_INPUT, literal(0))
  set_value(LAST_OUTPUT, literal(0))
end

def read_string(output, length)
  read(output)
  (1..length).each do |i|
    current_char = index(output, literal(i))
    set_addition(
      current_char,
      LAST_INPUT,
      current_char)
    set_value(
      current_char,
      select(
        group(current_char),
        literal(0xFF)))
    set_value(
      LAST_INPUT,
      current_char)
  end
end

def parse_string(output, input, length)
  set_value(output, literal(0))
  (1..length).each do |i|
    current_char = index(input, literal(i))
    set_value(
      output,
      select(
        supergroup(
          interleave(
            output,
            group(current_char))),
        literal(0b1010_1010_1010_1011)))
  end
end

def read_separator
  read_string(STRING_INPUT_SEPARATOR, 1)
end

def read_input
  read_string(STRING_INPUT_A, LENGTH_A)
  parse_string(NUMBER_A, STRING_INPUT_A, LENGTH_A)
  read_separator
  read_string(STRING_INPUT_B, LENGTH_B)
  parse_string(NUMBER_B, STRING_INPUT_B, LENGTH_B)
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
    index(STRING_OUTPUT, literal(1)),
    LAST_OUTPUT,
    literal(reversed_value)
  )
  write(STRING_OUTPUT)
  set_value(
    LAST_OUTPUT,
    literal(reversed_value)
  )
end

def write_string(string)
  string.chars.each do |char|
    write_char(char)
  end
end

def compare
  # TODO
end

def main
  initialize_arrays
  initialize_globals
  write_string("hello ick world\n")
  #read_input
  #compare
  exit_program
  execute_program("SUBSTR1a")
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

# Arrays subscripts start with 1
#    DO ,1 <- #4
#    DO ,1SUB#1 <- #3
#    DO ,1SUB#2 <- #6
#    DO ,1SUB#3 <- #9
#    DO ,1SUB#4 <- #12
#    DO READ OUT ,1SUB#1
#    DO READ OUT ,1SUB#2
#    PLEASE READ OUT ,1SUB#3
#    PLEASE READ OUT ,1SUB#4
#    PLEASE GIVE UP

# Read in chars (static lastin)
#    DO ,1 <- #4
#    DO WRITE IN ,1
#    DO READ OUT ,1SUB#1
#    DO READ OUT ,1SUB#2
#    DO READ OUT ,1SUB#3
#    PLEASE READ OUT ,1SUB#4
#    DO READ OUT ,1
#    PLEASE GIVE UP

# Output is all reversed bits
# But zero minus that (i.e. 256 - x) (static lastout)
#  '?' abcd efgh => hgfe dcba
#  '0' 0011 0000 => 0000 1100 =>  12 => 244
#  '1' 0011 0001 => 1000 1100 => 140 => 116
# '\n' 0000 1010 => 0101 0000 =>  80 => 176
