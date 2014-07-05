require 'cocoa/messageable'
require 'cocoa/filtered_observable'

module Cocoa
  class Channel
    include FilteredObservable
    include Messageable

    attr_accessor :name
    attr_observable :topic => :topic_change

    message_target :name

    def initialize(client)
      @client = client
      @name = nil
      @topic = nil
      @users = []

      init_observations
    end

    def users
      @users.map { |x| x[:user] }
    end

    def ops
      @users.select { |x| x[:mode] == :o }.map { |x| x[:user] }
    end

    def hops
      @users.select { |x| x[:mode] == :h }.map { |x| x[:user] }
    end

    def voices
      @users.select { |x| x[:mode] == :v }.map { |x| x[:user] }
    end

    def op?(user)
      user_mode(user) == :o
    end

    def hop?(user)
      user_mode(user) == :h
    end

    def voice?(user)
      user_mode(user) == :v
    end

    def add_user(user, prefix: nil)
      return if has_user? user

      prefix_to_mode = {'@' => :o, '%' => :h, '+' => :v}
      mode = prefix_to_mode[prefix]

      @users << { user: user, mode: mode }
      notify_observers(:user_join, self, user)
    end

    def delete_user(user, message: nil, kicked_by: nil)
      @users.delete_if { |x| x[:user].equal?(user) }
      
      if kicked_by
        notify_observers(:user_kick, self, user, kicked_by, message)
      else
        notify_observers(:user_part, self, user, message)
      end
    end

    def has_user?(user)
      @users.any? { |x| x[:user].equal?(user) }
    end

    def set_user_mode(user, mode)
      index = @users.index { |x| x[:user].equal?(user) }
      @users[index][:mode] = mode unless index.nil?
      notify_observers(:user_mode_change, self, @user)
    end

    def user_mode(user)
      index = @users.index { |x| x[:user].equal?(user) }
      @users[index][:mode] unless index.nil?
    end

    def on_message(event, to, from, message)
      notify_observers(:message, to, from, message)
    end

    def on_notice(event, to, from, message)
      notify_observers(:notice, to, from, message)
    end

    private

    def init_observations
      @client.add_observer(self) do |config|
        config.observe(:channel_message, :on_message).when { |chan| chan.equal?(self) }
        config.observe(:channel_notice, :on_message).when { |chan| chan.equal?(self) }
      end
    end
  end
end
