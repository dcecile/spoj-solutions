# frozen_string_literal: true

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
        write(3000)
        exit_program
      end

      def self.output
        output_numerals(400, 632, 3000)
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
    create_program("jumps to a label") do
      def initialize
        super
        @labels = make_labels(3)
        write(0)
        jump_and_push_stack(@labels[1])
        @labels.each_with_index do |label, i|
          label_nop(label)
          write(100 * (i + 1))
          exit_program
        end
      end

      def self.output
        output_numerals(0, 200)
      end
    end,
    create_program("jumps to stack items") do
      def initialize
        super
        @caller_block, @callee_block = make_labels(2)
        main
        caller_block
        callee_block
      end

      def main
        write(0)
        jump_and_push_stack(@caller_block)
        write(100)
        exit_program
      end

      def caller_block
        label_nop(@caller_block)
        jump_and_push_stack(@callee_block)
        write(200)
        pop_stack_and_jump(1)
        exit_program
      end

      def callee_block
        label_nop(@callee_block)
        write(300)
        pop_stack_and_jump(1)
        exit_program
      end

      def self.output
        output_numerals(0, 300, 200, 100)
      end
    end,
    create_program("discards stack items") do
      def initialize
        super
        @caller_block = make_label
        @callee_block = make_label
        main
        caller_block
        callee_block
      end

      def main
        write(0)
        jump_and_push_stack(@caller_block)
        write(100)
        exit_program
      end

      def caller_block
        label_nop(@caller_block)
        pop_stack_and_discard(0)
        jump_and_push_stack(@callee_block)
        write(200)
        exit_program
      end

      def callee_block
        label_nop(@callee_block)
        write(300)
        pop_stack_and_discard(1)
        pop_stack_and_jump(1)
        exit_program
      end

      def self.output
        output_numerals(0, 300, 100)
      end
    end,
    create_program("chooses path in if-else block") do
      def initialize
        super
        positive
        negative
        exit_program
      end

      def positive
        write(0)
        if_else_block(
          1,
          -> { write(100) },
          -> { write(200) }
        )
      end

      def negative
        write(300)
        if_else_block(
          0,
          -> { write(400) },
          -> { write(500) }
        )
      end

      def self.output
        output_numerals(0, 100, 300, 500)
      end
    end,
    create_program("loops a while block") do
      def initialize
        super
        @input = make_short
        read(@input)
        while_block(@input != 9) do
          write(@input)
          read(@input)
        end
        exit_program
      end

      def self.input
        "ONE\nFOUR\nFIVE\nSEVEN\nNINE\n"
      end

      def self.output
        output_numerals(1, 4, 5, 7)
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
    create_program("ands own bits") do
      def initialize
        super
        @result = make_short
        @result.value = 0b1101.self_and
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b0100)
      end
    end,
    create_program("ors own bits") do
      def initialize
        super
        @result = make_short
        @result.value = 0b1101.self_or.select(0x7FFF)
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b1111)
      end
    end,
    create_program("xors own bits") do
      def initialize
        super
        @result = make_short
        @result.value = 0b1101.self_xor.select(0x7FFF)
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b1011)
      end
    end,
    create_program("ands bits") do
      def initialize
        super
        @result = make_short(value: 0b1101)
        @result.value &= 0b1011
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b1001)
      end
    end,
    create_program("ors bits") do
      def initialize
        super
        @result = make_short(value: 0b1101)
        @result.value |= 0b1011
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b1111)
      end
    end,
    create_program("xors bits") do
      def initialize
        super
        @result = make_short(value: 0b1101)
        @result.value ^= 0b1011
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b0110)
      end
    end,
    create_program("inverts boolean") do
      def initialize
        super
        @result = make_short
        (0..1).each do |i|
          @result.value = i
          @result.value = !@result
          write(@result)
        end
        exit_program
      end

      def self.output
        output_numerals(1, 0)
      end
    end,
    create_program("compares equality") do
      def initialize
        super
        @result = make_short
        (0..7).each do |i|
          @result.value = 6
          @result.value = @result == i
          write(@result)
        end
        exit_program
      end

      def self.output
        output_numerals(0, 0, 0, 0, 0, 0, 1, 0)
      end
    end,
    create_program("compares inequality") do
      def initialize
        super
        @result = make_short
        (0..7).each do |i|
          @result.value = 6
          @result.value = @result != i
          write(@result)
        end
        exit_program
      end

      def self.output
        output_numerals(1, 1, 1, 1, 1, 1, 0, 1)
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
        @result.value = @array[
          0b0101.interleave(0b1010).select(0b1010)
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
        @result.value = compute
        write(@result)
        exit_program
      end

      def compute
        0b1111
          .interleave(0)
          .select(0b1111)
          .interleave(0)
          .select(0b1111)
          .interleave(0b1111_1111 .select(0b1111))
          .select(0b0111_1110)
      end

      def self.output
        output_numerals(0b10_1010)
      end
    end,
    create_program("shifts bits left one") do
      def initialize
        super
        @result = make_short(value: 0b01_1101_1000)
        @result.value <<= 1
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b11_1011_0000)
      end
    end,
    create_program("shifts bits left five") do
      def initialize
        super
        @result = make_short(value: 0b0111)
        @result.value <<= 5
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b111 << 5)
      end
    end,
    create_program("shifts bits right one") do
      def initialize
        super
        @result = make_short(value: 0b0111)
        @result.value >>= 1
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b0011)
      end
    end,
    create_program("shifts bits right five") do
      def initialize
        super
        @result = make_short(value: 0b0111_0110)
        @result.value >>= 5
        write(@result)
        exit_program
      end

      def self.output
        output_numerals(0b0111_0110 >> 5)
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
        @input = make_short_array(value: 10)
        read_string(@input, 10)
        parse_string(@number, @input, 10)
        write(@number)
        exit_program
      end

      def self.input
        "1001100110"
      end

      def self.output
        output_numerals(0b10_0110_0110)
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
    create_program("reads problem input") do
      include SubstringSolution

      def initialize
        super
        initialize_solution
        4.times do
          read_input
          write(@number_a)
          write(@number_b)
        end
        exit_program
      end

      def self.problems
        [
          [0b1001100110, 0b01101],
          [0b1100001100, 0b01000],
          [0b0101111101, 0b01010],
          [0b0010101101, 0b00000]
        ]
      end

      def self.input
        input_problems(problems)
      end

      def self.output
        output_numerals(*problems.flatten)
      end
    end,
    create_program("checks substrings") do
      include SubstringSolution

      def initialize
        super
        initialize_solution
        @number_a.value = 0b0010001001
        @number_b.value = 0b0000000010
        (0..5).each do |i|
          @is_substring.value = check_substring(i)
          write(@is_substring)
        end
        exit_program
      end

      def self.output
        output_numerals(0, 0, 1, 0, 0, 0)
      end
    end,
    create_program("solves") do
      include SubstringSolution

      def initialize
        super
        run_solution(self.class.problems.count)
      end

      def self.problems
        [
          [0b1111111111, 0b11111, 1],
          [0b0000000000, 0b00000, 1],
          [0b1111111111, 0b00000, 0],
          [0b0000000000, 0b11111, 0],
          [0b1010110010, 0b10110, 1],
          [0b1110111011, 0b10011, 0],
          [0b1111000000, 0b11110, 1],
          [0b1111110000, 0b10000, 1]
        ]
      end

      def self.input
        input_problems(problems)
      end

      def self.output
        problems
          .map { |problem| "#{problem[2]}\n" }
          .join
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
        expect(program.run(name, program_class.input)).to(
          succeed_and_output(program_class.output)
        )
      end
    end
  end
end
