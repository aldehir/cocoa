require 'cocoa/messageable'
require 'cocoa/synchronizable'

module Cocoa
  class User
    include Messageable
    include Synchronizable

    attr_accessor :nickname, :user, :host, :realname

    message_target :nickname
    synchronize :user, :host, :realname, method: :whois

    def initialize(client)
      @client = client
      @nickname = nil
      @user = nil
      @host = nil
      @realname = nil

      init_observations
    end

    def mask
      suffix = @host ? "@#{@host}" : ''
      suffix.prepend("!#{@user}") if @user && !suffix.empty?
      "#{@nickname}#{suffix}"
    end

    def whois(deferrable = nil)
      deferrable ||= EventMachine::DefaultDeferrable.new
      proxy = EventMachine::DefaultDeferrable.new
      proxy.callback { deferrable.succeed(self) }
      proxy.errback { deferrable.fail }

      @client.whois(@nickname, proxy)
      deferrable
    end

    def init_observations
      @client.add_observer(self) do |config|
        config.observe(:whois_reply, :on_whois_reply).when { |nick| nick == @nickname }
      end
    end

    def on_whois_reply(event, nickname, user, host, realname)
      @user = user
      @host = host
      @realname = realname
    end
  end
end
