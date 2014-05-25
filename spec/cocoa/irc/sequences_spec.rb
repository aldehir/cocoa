
lib_dir = File.expand_path(File.join(File.dirname(__FILE__), '../../../lib'))
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include? lib_dir
module Cocoa; module IRC; end; end

require 'cocoa/irc/raw_message'
require 'cocoa/irc/sequences'
IRC = Cocoa::IRC
Sequences = IRC::Sequences

describe Sequences::NamesSequence do
  let(:sequence) { Sequences::NamesSequence.new channel: '#cocoa' }

  describe "#replies" do
    it "should return [:rpl_namreply, :rpl_endofnames]" do
      sequence.replies.should eq([:rpl_namreply, :rpl_endofnames])
    end
  end

  describe "#end_replies" do
    it "should return :rpl_endofnames" do
      sequence.end_replies.should eq([:rpl_endofnames])
    end
  end

  context "after running NAMES #cocoa" do
    let(:messages) do
      messages = [
        IRC::RawMessage.new(:rpl_namreply, 'Cocoa', '=', '#cocoa', 'User @Cocoa'),
        IRC::RawMessage.new(:rpl_endofnames, 'Cocoa', '#cocoa', 'End of /NAMES List')
      ]
    end

    describe "#collect?" do
      it "should return true for all messages" do
        messages.each { |m| sequence.collect?(m).should be_true }
      end
    end

    describe "#stop?" do
      it "should return true for only the last message" do
        sequence.stop?(messages[0]).should be_false
        sequence.stop?(messages[1]).should be_true
      end
    end

    describe "#collect" do
      it "should call the callback when the last message is received" do
        cb = proc { |collected| collected.should.eq messages }
        cb.should_receive(:call)

        sequence.callback &cb
        messages.each { |m| sequence.collect(m) }
      end
    end
  end
end

describe Sequences::WhoisSequence do
  let(:sequence) { Sequences::WhoisSequence.new nickname: "Cocoa" }

  describe "#replies" do
    it "should return all possible replies for the WHOIS command" do
      expected = [:rpl_whoisuser, :rpl_whoisserver, :rpl_whoisoperator,
                  :rpl_whoisidle, :rpl_whoischanop, :rpl_whoischannels,
                  :rpl_endofwhois]
      sequence.replies.should eq(expected)
    end
  end

  describe "#end_replies" do
    it "should equal [:rpl_endofwhois]" do
      sequence.end_replies.should eq([:rpl_endofwhois])
    end
  end

  context "after sending a WHOIS Cocoa command" do
    let(:messages) do
      messages = [
        IRC::RawMessage.new(:rpl_whoisuser, 'Cocoa', 'Cocoa', ''),
        IRC::RawMessage.new(:rpl_whoisserver, 'Cocoa', 'Cocoa', ''),
        IRC::RawMessage.new(:rpl_whoisoperator, 'Cocoa', 'Cocoa', ''),
        IRC::RawMessage.new(:rpl_whoisidle, 'Cocoa', 'Cocoa', ''),
        IRC::RawMessage.new(:rpl_whoischanop, 'Cocoa', 'Cocoa', ''),
        IRC::RawMessage.new(:rpl_whoischannels, 'Cocoa', 'Cocoa', ''),
        IRC::RawMessage.new(:rpl_endofwhois, 'Cocoa', 'Cocoa', '')
      ]
    end

    describe "#collect?" do
      it "should return true for all messages" do
        messages.each { |m| sequence.collect?(m).should be_true }
      end
    end

    describe "#stop?" do
      it "should return true for only the last message" do
        messages[1..-2].each { |m| sequence.stop?(m).should be_false }
        sequence.stop?(messages[-1]).should be_true
      end
    end
  end
end
