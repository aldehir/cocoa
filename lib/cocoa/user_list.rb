require 'forwardable'

require 'cocoa/user'

module Cocoa
  class UserList
    include Enumerable
    extend Forwardable

    def_delegators :@users, :size, :length, :empty?
    def_delegator :@users, :keys, :nicknames
    def_delegator :@users, :values, :users
    def_delegator :@users, :each_value, :each

    def initialize(client)
      @client = client
      @users = {}

      init_observations
    end

    def add(user)
      @users[user.nickname] = user
    end
    alias_method :<<, :add

    def user(nickname)
      if include?(nickname)
        @users[nickname]
      else
        user = User.new(@client, nickname: nickname)
        add(user)
      end
    end
    alias_method :[], :user

    def delete(user)
      nickname = resolve_nick(user)
      @users.delete(nickname)
    end

    def include?(user)
      nickname = resolve_nick(user)
      @users.include? nickname
    end
    alias_method :has?, :include?

    def on_nick_change(event, old_nick, new_nick)
      user_obj = user(old_nick)
      user_obj.nickname = new_nick

      delete(old_nick)
      add(user_obj)
    end

    def on_whois_reply(event, nickname, user, host, realname)
      if include? nickname
        obj = self.user(nickname)
        obj.user = user
        obj.host = host
        obj.realname = realname
      else
        add(User.new(@client, nickname: nickname, user: user,
                     host: host, realname: realname))
      end
    end

    private

    def init_observations
      @client.add_observer(self) do |config|
        config.observe(:whois_reply, :on_whois_reply)
        config.observe(:nick_change, :on_nick_change)
        config.observe(:user_quit) do |event, user, message|
          delete(user)
        end
      end
    end

    def resolve_nick(user_or_nick)
      user_or_nick.is_a?(User) ? user_or_nick.nickname : user_or_nick
    end
  end
end
