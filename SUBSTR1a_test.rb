require "tmpdir"
require "SUBSTR1a_test_helper"
require "SUBSTR1a"

using Expressions::Refinements

RSpec.describe Program do
  test_programs = [
    create_program("exits") do
      def initialize
        super
        exit_program
      end

      def self.output
        ""
      end
    end,
    create_program("writes numbers") do
      def initialize
        super
        write(400)
        write(632)
        exit_program
      end

      def self.output
        output_numerals(400, 632)
      end
    end,
    create_program("reads numbers") do
      def initialize
        super
        @number_input = make_short
        read(@number_input)
        write(@number_input)
        read(@number_input)
        write(@number_input)
        exit_program
      end

      def self.input
        "FOUR\nFIVE\n"
      end

      def self.output
        output_numerals(4, 5)
      end
    end,
    create_program("sets and gets basic reference") do
      def initialize
        super
        @number = make_short
        @number.value = 231
        write(@number)
        exit_program
      end

      def self.output
        output_numerals(231)
      end
    end,
    create_program("indexes arrays") do
      def initialize
        super
        @array = make_short_array(value: 2)
        @array[1].value = 13
        @array[2].value = 19
        write(@array[1])
        write(@array[2])
        exit_program
      end

      def self.output
        output_numerals(13, 19)
      end
    end,
    create_program("interleaves bits") do
      def initialize
        super
        @result = make_short
        @result.value = 0b0101.interleave(0b1010)
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b0110_0110)
      end
    end,
    create_program("selects bits") do
      def initialize
        super
        @result = make_short
        @result.value = 0b1101.select(0b1010)
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b0010)
      end
    end,
    create_program("nests one group") do
      def initialize
        super
        @result = make_short
        @result.value =
          0b0101
          .interleave(0b1010)
          .select(0b1010)
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b0001)
      end
    end,
    create_program("nests two groups") do
      def initialize
        super
        @array = make_short_array(value: 2)
        @array[1].value = 13
        @array[2].value = 19
        @result = make_short
        @result.value =
          @array[
            0b0101
            .interleave(0b1010)
            .select(0b1010)
          ]
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(13)
      end
    end,
    create_program("nests multiple groups") do
      def initialize
        super
        @result = make_short
        @result.value =
          0b1111
          .interleave(0)
          .select(0b1111)
          .interleave(0)
          .select(0b1111)
          .interleave(
            0b1111_1111
            .select(0b1111)
          )
          .select(0b0111_1110)
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b10_1010)
      end
    end,
    create_program("shifts bits left one") do
      def initialize
        super
        @result = make_short
        @result.value = 0b0111.shift_left_one
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b1110)
      end
    end,
    create_program("adds") do
      def initialize
        super
        @result = make_short
        set_addition(
          @result,
          329,
          210
        )
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(329 + 210)
      end
    end,
    create_program("subtracts") do
      def initialize
        super
        @result = make_short
        set_subtraction(
          @result,
          329,
          210
        )
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(329 - 210)
      end
    end,
    create_program("reads text") do
      def initialize
        super
        @input = make_short_array(value: 3)
        read_string(@input, 3)
        write(@input[1])
        write(@input[2])
        write(@input[3])
        exit_program
      end

      def self.input
        "Ick"
      end

      def self.output
        output_numerals(*input.codepoints)
      end
    end,
    create_program("reads binary") do
      def initialize
        super
        @number = make_short
        @input = make_short_array(value: 8)
        read_string(@input, 8)
        parse_string(@number, @input, 8)
        write(@number)
        exit_program
      end

      def self.input
        "11010111"
      end

      def self.output
        output_numerals(0b11010111)
      end
    end,
    create_program("writes text") do
      def initialize
        super
        write_string("hello ick world\n")
        exit_program
      end

      def self.output
        "hello ick world\n"
      end
    end,
    create_program("solves") do
      include SubstringSolution

      def initialize
        super
        run_solution
      end

      def self.input
        "1101 10"
      end

      def self.output
        output_numerals(0b1101, 0b10)
      end
    end
  ]
  test_programs.each do |program_class|
    it program_class.name do
      Dir.mktmpdir do |dir|
        name = "#{dir}/test"
        program = program_class.new
        program.write_source(name)
        expect(program.compile(name)).to succeed_and_output("")
        expect(program.run(name, program_class.input)).to succeed_and_output(program_class.output)
      end
    end
  end
end
