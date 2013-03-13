require 'bwoken/formatter'

module Bwoken::XunitFormatter

  ##
  # based on the code by @sebastianludwig as a part of tuneup.js
  # https://github.com/alexvollmer/tuneup_js/blob/master/test_runner/xunit_output.rb
  ##
  class TestSuite
    attr_reader :name, :timestamp
    attr_accessor :test_cases

    def initialize(name)
      @name = name
      @test_cases = []
      @timestamp = DateTime.now
    end

    def failures
      @test_cases.count { |test| test.failed? }
    end

    def time
      @test_cases.map { |test| test.time }.inject(:+)
    end
  end

  class TestCase
    attr_reader :name
    attr_accessor :messages

    def initialize(name)
      @name     = name
      @messages = []
      @failed   = true
      @start    = Time.now
      @finish   = nil
    end

    def <<(message)
      @messages << message
    end

    def pass!
      @failed = false;
      @finish = Time.now
    end

    def fail!
      @finish = Time.now
    end

    def failed?
      @failed
    end

    def time
      return 0 if @finish.nil?
      @finish - @start
    end
  end

  class XunitOutput
    attr_reader :suite

    def initialize(filename)
      @filename = filename
      @suite = TestSuite.new(File.basename(filename, File.extname(filename)))
    end

    def add(line)
      return if @suite.test_cases.empty?
      @suite.test_cases.last << line
    end

    def add_status(status, msg)
      case status
      when :start
        @suite.test_cases << TestCase.new(msg)
      when :pass
        @suite.test_cases.last.pass!
      when :fail
        @suite.test_cases.last.fail!
      end
    end

    def close
      File.open(@filename, 'w') { |f| f.write(serialize(@suite)) }
    end

    def xml_escape(input)
       result = input.dup

       result.gsub!("&", "&amp;")
       result.gsub!("<", "&lt;")
       result.gsub!(">", "&gt;")
       result.gsub!("'", "&apos;")
       result.gsub!("\"", "&quot;")

       return result
    end

    def serialize(suite)
      output = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" << "\n"
      output << "<testsuite name=\"#{xml_escape(suite.name)}\" timestamp=\"#{suite.timestamp}\" time=\"#{suite.time}\" tests=\"#{suite.test_cases.count}\" failures=\"#{suite.failures}\">" << "\n"

      suite.test_cases.each do |test|
        output << "  <testcase name=\"#{xml_escape(test.name)}\" time=\"#{test.time}\">" << "\n"
        if test.failed?
          output << "    <failure>#{test.messages.map { |m| xml_escape(m) }.join("\n")}</failure>" << "\n"
        end
        output << "  </testcase>" << "\n"
      end

      output << "</testsuite>" << "\n"
    end
  end

  class Formatter < Bwoken::Formatter

    def initialize(filename)
      @output = XunitOutput.new(filename)
    end

    on :complete do |line|
      @output.close
    end

    on :error do |line|
      tokens = line.split(' ')
      @output.add(tokens[4..-1].join(' ')) if line.include?('Exception')
    end

    on :fail do |line|
      tokens = line.split(' ')
      @output.add_status(:fail, tokens[4..-1].join(' '))
    end

    on :start do |line|
      tokens = line.split(' ')
      @output.add_status(:start, tokens[4..-1].join(' '))
    end

    on :pass do |line|
      tokens = line.split(' ')
      @output.add_status(:pass, tokens[4..-1].join(' '))
    end
  end
end
