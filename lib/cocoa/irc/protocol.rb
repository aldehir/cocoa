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

    def nick(nickname, callback = nil, errback = nil, &block)
      message = RawMessage.new(:nick, nickname)
      sequence = Seq::NickSequence.new(nickname: nickname,
                                       old_nickname: @identity.nickname)

      # If successful, change our identity to the nickname
      sequence.callback do |messages|
        nick_msg = messages.first
        @identity.nickname = nick_msg.params.last
      end

      command(message, sequence, callback, errback, &block)
    end

    def join(channel, callback = nil, errback = nil, &block)
      message = RawMessage.new(:join, channel)
      sequence = Seq::JoinSequence.new(
        channel: channel,
        nickname: @identity.nickname
      )

      command(message, sequence, callback, errback, &block)
    end

    def names(channel, callback = nil, errback = nill, &block)
      message = RawMessage.new(:names, channel)
      sequence = Seq::NamesSequence.new(channel: channel)
      command(message, sequence, callback, errback, &block)
    end

    def command(message, sequence, callback = nil, errback = nil, &block)
      sequence.callback(&block) if block_given?
      sequence.callback(&callback) if callback
      sequence.errback(&errback) if errback
      sequence.errback do |_, timedout|
        @active_sequences.delete(sequence) if timedout
      end

      @active_sequences << sequence
      [*message].each { |m| send_message(m) }
    end

    def subscribe(command, method=nil, &block)
      if method
        @subscriptions[command] << method
      elsif block_given?
        @subscriptions[command] << block
      end
    end

    def connection_completed
      sequence = Seq::NickUserSequence.new
      nick_msg = RawMessage.new(:nick, @identity.nickname)
      user_msg = RawMessage.new(:user, @identity.user, '0', '*',
                                @identity.realname)

      nick_attempts = 1
      handle_bad_name = lambda do |m, timedout|
        handle = [:err_nickcollision, :err_nicknameinuse]
        return register_failed(m) unless m and handle.include? m.command
        return register_failed(m) if nick_attempts >= @max_nick_attempts

        @identity.nickname += '_'
        command(RawMessage.new(:nick, @identity.nickname),
                Seq::NickUserSequence.new, method(:register_succeeded),
                handle_bad_name)
        nick_attempts += 1
      end

      command([nick_msg, user_msg], sequence, method(:register_succeeded),
              handle_bad_name)
    end

    def register_succeeded(messages); end
    def register_failed(message); end

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
        @subscriptions[msg.command].each do |cb|
          if cb.is_a? Proc
            cb.call(msg)
          else
            send(cb, msg)
          end
        end
      end

      collect_sequences(msg)
    end

    def collect_sequences(msg)
      stopped = []
      @active_sequences.each do |sequence|
        if sequence.stop? msg
          stopped << sequence
        elsif sequence.collect? msg
          sequence.collect(msg)
        end
      end

      stopped.each do |seq|
        seq.collect(msg)
        @active_sequences.delete(seq)
      end
    end
  end
end
