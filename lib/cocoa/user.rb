require 'cocoa/messageable'
require 'cocoa/synchronizable'
require 'cocoa/filtered_observable'

module Cocoa
  class User
    include FilteredObservable
    include Messageable
    include Synchronizable

    attr_accessor :user, :host, :realname
    attr_observable :nickname => :nick_change

    message_target :nickname
    synchronize :user, :host, :realname, method: :whois

    def initialize(client, **opts)
      @client = client
      @nickname = opts[:nickname]
      @user = opts[:user]
      @host = opts[:host]
      @realname = opts[:realname]
    end

    def mask
      suffix = @host ? "@#{@host}" : ''
      suffix.prepend("!#{@user}") if @user && !suffix.empty?
      "#{@nickname}#{suffix}"
    end

    def me?
      @client.identity.nickname.casecmp(@nickname) == 0
    end

    def whois(deferrable = nil, &block)
      deferrable ||= EventMachine::DefaultDeferrable.new
      deferrable.callback(&block) if block_given?

      proxy = EventMachine::DefaultDeferrable.new
      proxy.callback { deferrable.succeed(self) }
      proxy.errback { deferrable.fail }

      @client.whois(@nickname, proxy)
      deferrable
    end
  end
end
