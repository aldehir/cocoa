require 'cocoa/irc/sequences'
require 'cocoa/irc/raw_message'

Seq = Cocoa::IRC::Sequences

module Cocoa::IRC
  class CommandFactory
    def initialize(client)
      @client = client
    end

    def create(command, *args)
      command = command.to_sym unless command.is_a? Symbol
      return send(command, *args) if respond_to? command
      nil
    end

    def join(channel)
      message = RawMessage.new(:join, channel)
      sequence = Seq::JoinSequence.new(
        channel: channel,
        nickname: @client.identity.nickname
      )

      [message, sequence]
    end

    def part(channel)
      message = RawMessage.new(:part, channel)
      sequence = Seq::PartSequence.new(
        channel: channel,
        nickname: @client.identity.nickname
      )

      [message, sequence]
    end

    def nick(nickname)
      message = RawMessage.new(:nick, nickname)
      sequence = Seq::NickSequence.new(nickname: nickname,
                                       old_nickname: @client.identity.nickname)

      [message, sequence]
    end

    def nick_user(nickname, user, realname)
      nick_msg = RawMessage.new(:nick, nickname)
      user_msg = RawMessage.new(:user, user, '0', '*', realname)
      sequence = Seq::NickUserSequence.new

      return [[nick_msg, user_msg], sequence]
    end

    def quit(message)
      message = RawMessage.new(:quit, message)
      sequence = Seq::QuitSequence.new
      
      [message, sequence]
    end

    def names(channel)
      message = RawMessage.new(:names, channel)
      sequence = Seq::NamesSequence.new(channel: channel)
      
      [message, sequence]
    end

    def whois(nickname)
      message = RawMessage.new(:whois, nickname)
      sequence = Seq::WhoisSequence.new(nickname: nickname)

      [message, sequence]
    end
  end
end
