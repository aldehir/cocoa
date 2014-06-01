require 'eventmachine'
require 'logger'
require 'ostruct'

require 'cocoa/irc/raw_message'
require 'cocoa/irc/sequences'

Seq = Cocoa::IRC::Sequences

module Cocoa::IRC
  module Protocol
    include EventMachine::Protocols::LineProtocol

    attr_reader :identity

    def initialize(nickname, user, realname, max_nick_attempts: 3)
      @max_nick_attempts = max_nick_attempts
      @identity = OpenStruct.new(
        nickname: nickname,
        user: user,
        realname: realname
      )

      @subscriptions = Hash.new { |h, k| h[k] = [] }
      @active_sequences = []

      subscribe(:ping, :on_ping)
    end

    def on_ping(msg)
      pong = RawMessage.new(:pong, *msg.params)
      send_message(pong)
    end

    def nick(nickname, callback = nil, errback: nil, &block)
      message = RawMessage.new(:nick, nickname)
      sequence = Seq::NickSequence.new(nickname: nickname,
                                       old_nickname: @identity.nickname)

      # If successful, change our identity to the nickname
      sequence.callback do |messages|
        nick_msg = messages.first
        @identity.nickname = nick_msg.params.last
      end

      command(message, sequence, callback, errback: errback, &block)
    end

    def join(channel, callback = nil, errback: nil, timeout: nil, &block)
      message = RawMessage.new(:join, channel)
      sequence = Seq::JoinSequence.new(
        channel: channel,
        nickname: @identity.nickname
      )

      command(message, sequence, callback, errback: errback, timeout: timeout,
              &block)
    end

    def part(channel, callback = nil, errback: nil, timeout: nil, &block)
      message = RawMessage.new(:part, channel)
      sequence = Seq::PartSequence.new(
        channel: channel,
        nickname: @identity.nickname
      )

      command(message, sequence, callback, errback: errback, timeout: timeout,
              &block)
    end

    def quit(message)
      message = RawMessage.new(:quit, message)
      sequence = Seq::QuitSequence.new

      stop_eventmachine = proc { EventMachine.stop }
      command(message, sequence, stop_eventmachine, errback: stop_eventmachine,
              timeout: stop_eventmachine)
    end

    def names(channel, callback = nil, errback: nil, timeout: nil, &block)
      message = RawMessage.new(:names, channel)
      sequence = Seq::NamesSequence.new(channel: channel)
      command(message, sequence, callback, errback: errback,
              timeout: timeout, &block)
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

    def connection_completed
      sequence = Seq::NickUserSequence.new
      nick_msg = RawMessage.new(:nick, @identity.nickname)
      user_msg = RawMessage.new(:user, @identity.user, '0', '*',
                                @identity.realname)

      nick_attempts = 1
      handle_bad_name = lambda do |m|
        handle = [:err_nickcollision, :err_nicknameinuse]
        return register_failed(m) unless handle.include? m.command
        return register_failed(m) if nick_attempts >= @max_nick_attempts

        @identity.nickname += '_'
        command(RawMessage.new(:nick, @identity.nickname),
                Seq::NickUserSequence.new, method(:register_succeeded),
                errback: handle_bad_name, timeout: method(:register_timeout))
        nick_attempts += 1
      end

      command([nick_msg, user_msg], sequence, method(:register_succeeded),
              errback: handle_bad_name, timeout: method(:register_timeout))
    end

    def register_succeeded(messages); end
    def register_failed(message); end
    def register_timeout(); end

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
