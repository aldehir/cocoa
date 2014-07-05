require 'eventmachine'
require 'logger'
require 'ostruct'

require 'cocoa/irc/raw_message'
require 'cocoa/irc/sequences'
require 'cocoa/irc/command_factory'

module Cocoa::IRC
  module Protocol
    include EventMachine::Protocols::LineProtocol

    attr_reader :identity

    def initialize
      super

      @subscriptions = Hash.new { |h, k| h[k] = [] }
      @active_sequences = []
    end

    def command(message, sequence, callback = nil, errback: nil, timeout: nil,
                &block)
      sequence.callback(&block) if block_given?
      sequence.callback(&callback) if callback
      sequence.errback(&errback) if errback
      sequence.timeout_callback(&timeout) if timeout
      sequence.timeout_callback { @active_sequences.delete(sequence) }

      @active_sequences << sequence
      [*message].each { |m| send_message(m) }
    end

    def subscribe(command, meth = nil, &block)
      @subscriptions[command] << method(meth) if meth
      @subscriptions[command] << block if block_given?
    end

    def send_message(msg)
      send_line(msg.to_s)
    end

    def receive_message(msg)
      publish(msg)
    end

    def receive_line(line)
      parsed = RawMessage.parse(line)
      receive_message(parsed)
    end

    def send_line(line)
      send_data(line + "\r\n")
    end

    protected

    def publish(msg)
      if @subscriptions.key? msg.command
        @subscriptions[msg.command].each { |cb| cb.call(msg) }
      end

      collect_sequences(msg)
    end

    def collect_sequences(msg)
      stopped = []
      @active_sequences.each do |sequence|
        stopped.push(sequence) && next if sequence.stop?(msg)
        sequence.collect(msg) if sequence.collect?(msg)
      end

      stopped.each do |seq|
        seq.collect(msg)
        @active_sequences.delete(seq)
      end
    end
  end
end
