require 'forwardable'

require 'cocoa/channel'

module Cocoa
  class ChannelList
    include Enumerable
    extend Forwardable

    def_delegators :@channels, :size, :length, :empty?
    def_delegator :@channels, :keys, :names
    def_delegator :@channels, :values, :channels
    def_delegator :@channels, :each_value, :each

    def initialize(client)
      @client = client
      @channels = {}

      init_observations
    end

    def add(channel)
      @channels[channel.name] = channel
    end
    alias_method :<<, :add

    def channel(name)
      @channels[name]
    end
    alias_method :[], :channel

    def delete(channel)
      name = resolve_name(channel)
      @channels.delete(name)
    end

    def include?(channel)
      name = resolve_name(channel)
      @channels.include? name
    end
    alias_method :has?, :include?

    private

    def init_observations
      @client.add_observer(self) do |config|
        config.observe(:topic_change) do |_event, channel, topic|
          channel.topic = topic
        end

        config.observe(:user_join) do |_event, channel, user|
          channel.add_user(user)
        end

        config.observe(:user_part) do |_event, chan, user, message|
          chan.delete_user(user, message: message)
        end

        config.observe(:user_kick) do |_event, chan, user, by, message|
          chan.delete_user(user, message: message, kicked_by: by)
        end

        config.observe(:user_quit) do |_event, user, message|
          self.each do |chan|
            chan.delete_user(user, message: message) if chan.has_user? user
          end
        end
      end
    end

    def resolve_name(channel_or_name)
      if channel_or_name.is_a? Channel
        channel_or_name.name
      else
        channel_or_name
      end
    end

  end
end
