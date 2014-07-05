require 'cocoa/channel'
require 'cocoa/user'

module Cocoa::Builders
  class ChannelBuilder
    def initialize(client)
      @client = client
      @channel = Cocoa::Channel.new(client)
    end

    def result
      @channel
    end

    def build(messages)
      [*messages].each do |message|
        method = "#{message.command.to_s}_msg".to_sym
        send(method, message) if respond_to? method
      end
    end

    def self.build(messages)
      builder = ChannelBuilder.new
      builder.build(messages)
      builder.result
    end

    def join_msg(message)
      @channel.name = message.params.last
    end

    def rpl_topic_msg(message)
      @channel.topic = message.params.last
    end

    def rpl_namreply_msg(message)
      users = message.params.last.split().map { |n| n.sub(/^[@+%]/, '') }
     
      users.map! do |nickname|
        user = Cocoa::User.new(@client)
        user.nickname = nickname
        user
      end

      @channel.users += users
    end
  end
end
