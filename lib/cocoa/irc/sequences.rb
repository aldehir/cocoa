require 'eventmachine'
require 'cocoa/irc/collectable'

module Cocoa::IRC
  module Sequences
    class Sequence
      include EventMachine::Deferrable
      include Collectable

      def initialize(**args, &block)
        super(**args)
        callback &block if block_given?
      end

      def collect(message)
        super

        if error? message
          fail(message)
        elsif stop? message
          succeed(@messages)
        end
      end
    end

    class NickSequence < Sequence
      collect do |c|
        c.add_reply :nick, match: { nickname: 0 }, from: :old_nickname
        c.add_error_reply :err_nicknameinuse, :err_nickcollision,
                          :err_erroneusnickname,
                          match: { nickname: 0 }
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
