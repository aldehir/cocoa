require 'eventmachine'
require 'cocoa/irc/collectable'

module Cocoa::IRC
  module Sequences
    class Sequence
      include EventMachine::Deferrable
      include Collectable

      def initialize(**args, &block)
        timeout = args.delete(:timeout)

        super(**args)
        callback &block if block_given?
        timeout(timeout || 5, nil, true)
      end

      def collect(message)
        super

        if error? message
          fail(message, false)
        elsif stop? message
          succeed(@messages)
        end
      end
    end

    class NickUserSequence < Sequence
      collect do |c|
        c.add_end_reply :rpl_welcome
        c.add_error_reply :err_nicknameinuse, :err_nickcollision,
                          :err_erroneusnickname, :err_restricted,
                          :err_alreadyregistred
      end
    end

    class NickSequence < Sequence
      collect do |c|
        c.add_end_reply :nick, match: { nickname: 0 }, from: :old_nickname
        c.add_error_reply :err_nicknameinuse, :err_nickcollision,
                          :err_erroneusnickname, :err_restricted,
                          match: { nickname: 1 }
      end
    end

    class JoinSequence < Sequence
      collect do |c|
        c.add_reply :join, match: { channel: 0 }, from: :nickname
        c.add_reply :rpl_topic, match: { channel: 1 }
        c.add_reply :rpl_namreply, match: { channel: 2 }
        c.add_end_reply :rpl_endofnames, match: { channel: 1 }
        c.add_error_reply :err_bannedfromchan, :err_badchannelkey,
                          :err_badchanmask, :err_toomanychannels,
                          :err_toomanytargets, :err_inviteonlychan,
                          :err_nosuchchannel, match: { channel: 1 }
      end
    end

    class PartSequence < Sequence
      collect do |c|
        c.add_end_reply :part, match: { channel: 0 }, from: :nickname
        c.add_error_reply :err_notonchannel, :err_nosuchchannel,
                          match: { channel: 0 }
      end
    end

    class QuitSequence < Sequence
      collect { |c| c.add_end_reply :error }
    end

    class NamesSequence < Sequence
      collect do |c|
        c.add_reply :rpl_namreply, match: { channel: 2 }
        c.add_end_reply :rpl_endofnames, match: { channel: 1 }
      end
    end

    class WhoSequence < Sequence
      collect do |c|
        c.add_reply :rpl_whoreply, :rpl_endofwho,
                    match: { channel: 1 }, has_end: true
      end
    end

    class WhoisSequence < Sequence
      collect do |c|
        c.add_reply :rpl_whoisuser, :rpl_whoisserver, :rpl_whoisoperator,
                    :rpl_whoisidle, :rpl_whoischanop, :rpl_whoischannels,
                    :rpl_endofwhois, match: { nickname: 1 }, has_end: true
      end
    end
  end
end
