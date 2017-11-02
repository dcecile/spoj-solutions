require "tmpdir"
require "rspec/expectations"
require "SUBSTR1a.rb"

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

RSpec.describe Program do
  it "runs" do
    Dir.mktmpdir do |dir|
      name = "#{dir}/test"
      #write(literal(100000))
      write(literal(1))
      #write(literal(1))
      exit_program
      program = Program.instance
      program.write(name)
      expect(program.compile(name)).to succeed_and_output("")
      expect(program.run(name)).to succeed_and_output(" \nI\n")
    end
  end
end
