require 'cocoa/messageable'

module Cocoa
  class Channel
    include Messageable

    attr_accessor :name, :topic, :users

    message_target :name

    def initialize(client)
      @client = client
      @name = nil
      @topic = nil
      @users = []

      init_observations
    end

    def init_observations
      @client.add_observer(self) do |config|
        config.observe(:topic_changed, :on_topic_changed).when { |c| c == @name }
        config.observe(:user_joined, :on_user_join).when { |c| c == @name }
      end
    end

    def on_topic_changed(event, channel, topic)
      @client.log.info("Topic changed for channel: #{topic}")
    end

    def on_user_join(event, channel, user)
    end

  end
end
