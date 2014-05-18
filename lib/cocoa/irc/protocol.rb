require 'eventmachine'
require 'logger'
require 'ostruct'

require 'cocoa/irc/raw_message'

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
    end

    def connection_completed
      send_message(RawMessage.new(:nick, @identity.nickname))
      send_message(RawMessage.new(:user, @identity.user, '0', '*',
                                  @identity.realname))
    end

    def send_message(msg)
      send_line(msg.to_s)
    end

    def receive_message(msg)
      if msg.command == :ping
        pong = RawMessage.new(:pong, *msg.params)
        send_message(pong)
      end
    end

    def receive_line(line)
      parsed = RawMessage.parse(line)
      receive_message(parsed)
    end

    def send_line(line)
      send_data(line + "\r\n")
    end
  end
end
