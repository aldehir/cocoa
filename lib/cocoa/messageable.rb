require 'cocoa/irc/raw_message'

module Cocoa
  module Messageable
    def self.included(base)
      base.extend(ClassMethods)
    end

    def message(message)
      msg = IRC::RawMessage.new(:privmsg, target, message)
      EventMachine.next_tick { client.send_message(msg) }
    end

    def notice(message)
      msg = IRC::RawMessage.new(:notice, target, message)
      EventMachine.next_tick { client.send_message(msg) }
    end

    module ClassMethods
      def message_target(var, send_with: :client)
        class_eval do
          class_variable_set(:@@message_target, var)
          class_variable_set(:@@message_client, send_with)
        end
      end
    end

    private

    def client
      variable = self.class.class_variable_get(:@@message_client)
      instance_variable_get("@#{variable}")
    end

    def target
      variable = self.class.class_variable_get(:@@message_target)
      instance_variable_get("@#{variable}")
    end
  end
end
