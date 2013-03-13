require 'spec_helper'

require 'bwoken/formatters/xunit_formatter'

describe Bwoken::XunitFormatter::TestSuite do
  subject { described_class.new('FakeProject') }

  describe '.failures' do
    context 'when contain failed test case' do
      before { subject.test_cases << Bwoken::XunitFormatter::TestCase.new('foo') }
      it 'returns number of failed cases' do
        subject.failures.should == 1
      end
    end
  end

  describe '.time' do
    before do
      foo = Bwoken::XunitFormatter::TestCase.new('foo')
      bar = Bwoken::XunitFormatter::TestCase.new('bar')
      foo.stub(:time => 10)
      bar.stub(:time => 1)
      subject.test_cases << foo
      subject.test_cases << bar
    end

    it 'returns number of seconds cosumed for all cases' do
      subject.time.should == 11
    end
  end
end

describe Bwoken::XunitFormatter::TestCase do
  subject { described_class.new('FakeTest') }

  describe '.pass!' do
    before do
      time = Time.now
      Time.stub(:now => time)
      subject << 'Triggering creation'
      Time.stub(:now => time + 2)
      subject.pass!
    end

    it 'changes case status to passed' do
      subject.failed?.should == false;
    end

    it 'saves finished time' do
      subject.time.should == 2
    end
  end

  describe '.fail!' do
    before do
      time = Time.now
      Time.stub(:now => time)
      subject << 'Triggering creation'
      Time.stub(:now => time + 2)
      subject.fail!
    end

    it 'saves finished time' do
      subject.time.should == 2
    end
  end

  describe '.failed?' do
    context 'when test failed' do
      it 'returns true' do
        subject.failed?.should == true
      end
    end

    context 'when test passed' do
      before { subject.pass! }
      it 'returns false' do
        subject.failed?.should == false
      end
    end
  end

  describe '.time' do
    context 'when test finished' do
      before do
        time = Time.now
        Time.stub(:now => time)
        subject << 'Triggering creation'
        Time.stub(:now => time + 2)
        subject.pass!
      end

      it 'returns number of seconds consumed by test case' do
        subject.time.should == 2
      end
    end

    context 'when test is not finished' do
      it 'returns 0' do
        subject.time.should == 0
      end
    end
  end
end

describe Bwoken::XunitFormatter::XunitOutput do
  subject { described_class.new('fake_file_path') }

  describe '.add' do
    before { subject.add_status(:start, '') }
    it 'appends line to the last test case' do
      subject.suite.test_cases.last.should_receive(:<<).with('foo')
      subject.add('foo')
    end
  end

  describe '.addStatus' do
    context 'with :start' do
      it 'creates new test case' do
        subject.suite.test_cases.should_receive(:<<)
        subject.add_status(:start, '')
      end
    end

    context 'with :pass' do
      before { subject.add_status(:start, '') }
      it 'changes last test case status to passed' do
        subject.suite.test_cases.last.should_receive(:pass!)
        subject.add_status(:pass, '')
      end
    end

    context 'with :fail' do
      before { subject.add_status(:start, '') }
      it 'changes last test case status to failed' do
        subject.suite.test_cases.last.should_receive(:fail!)
        subject.add_status(:fail, '')
      end
    end
  end

  describe '.close' do
    it 'writes serialized test suite to the file' do
      File.should_receive(:open).with('fake_file_path', 'w')
      subject.close
    end
  end

  describe '.serialize' do
    before do
      @datetime = DateTime.now
      DateTime.stub(:now => @datetime)

      @time = Time.now
      Time.stub(:now => @time)

      subject.add_status(:start, 'failed case')
      subject.add('foo')
      subject.add_status(:fail, '')
      subject.add_status(:start, 'passed case')
      subject.add_status(:pass, '')
    end

    it 'returns test suite as xml document' do
      subject.serialize(subject.suite).should == <<-XML
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<testsuite name="fake_file_path" timestamp="#{@datetime}" time="0.0" tests="2" failures="1">
  <testcase name="failed case" time="0.0">
    <failure>foo</failure>
  </testcase>
  <testcase name="passed case" time="0.0">
  </testcase>
</testsuite>
      XML
    end
  end
end
