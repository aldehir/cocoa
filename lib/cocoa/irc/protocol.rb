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
      subscribe(:err_nicknameinuse, :on_nickname_in_use)
    end

    def on_ping(msg)
      pong = RawMessage.new(:pong, *msg.params)
      send_message(pong)
    end

    def on_nickname_in_use(msg)
      @identity.nickname += '_'
      nick = RawMessage.new(:nick, @identity.nickname)
      send_message(nick)
    end

    def nick(nickname, **opts, &block)
      message = RawMessage.new(:nick, nickname)
      sequence = Seq::NickSequence.new(nickname: nickname,
                                       old_nickname: @identity.nickname)

      # If successful, change our identity to the nickname
      sequence.callback do |messages|
        nick_msg = messages.first
        @identity.nickname = nick_msg.params.last
      end

      command(message, sequence, **opts, &block)
    end

    def join(channel, **opts, &block)
      message = RawMessage.new(:join, channel)
      sequence = Seq::JoinSequence.new(
        channel: channel,
        nickname: @identity.nickname
      )

      command(message, sequence, **opts, &block)
    end

    def names(channel, **opts, &block)
      message = RawMessage.new(:names, channel)
      sequence = Seq::NamesSequence.new(channel: channel)
      command(message, sequence, **opts, &block)
    end

    def command(message, sequence, callback: nil, errback: nil, &block)
      sequence.callback(&block) if block_given?
      sequence.callback(&callback) if callback
      sequence.errback(&errback) if errback
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
      nick(@identity.nickname)
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
