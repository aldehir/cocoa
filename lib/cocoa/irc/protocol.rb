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

    def initialize(nickname, user, realname)
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

      send_message(message)
    end

    def subscribe(command, method=nil, &block)
      if method
        @subscriptions[command] << method
      elsif block_given?
        @subscriptions[command] << block
      end
    end

    def connection_completed
      reattempt_nick = proc do |m, timedout|
        unless timedout
          @identity.nickname += '_'
          nick(@identity.nickname, errback: reattempt_nick)
        end
      end

      nick(@identity.nickname, errback = reattempt_nick)
      send_message(RawMessage.new(:user, @identity.user, '0', '*',
                                  @identity.realname))
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
        @subscriptions[msg.command].each do |cb|
          if cb.is_a? Proc
            cb.call(msg)
          else
            send(cb, msg)
          end
        end
      end

      @active_sequences.delete_if do |sequence|
        sequence.collect(msg) if sequence.collect?(msg)
        sequence.stop?(msg)
      end
    end
  end
end
