require 'eventmachine'

module Cocoa::IRC
  module Collectable
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do
        include Configurable
        include InstanceMethods
      end
    end

    module ClassMethods
      def collect(&block)
        configuration_class = Class.new { include Configurable }
        configuration = configuration_class.new
        yield configuration

        define_method(:reply_map) { configuration.reply_map }
      end
    end

    module InstanceMethods
      attr_reader :messages

      def initialize(**args)
        super()

        @arguments = args
        @messages = []
      end

      def replies
        reply_map.keys
      end

      def error_replies
        reply_map.select { |k, v| v[:error] }.keys
      end

      def end_replies
        reply_map.select { |k, v| v[:end] || v[:error] }.keys
      end
      def collect(message)
        @messages << message if collect? message
      end

      def collect?(message)
        cmd = message.command
        return false unless reply_map.include?(cmd)

        from = reply_map[cmd][:from]
        return false if from && message.nickname.casecmp(@arguments[from]) != 0

        reply_map[cmd][:match].to_a.map do |k, v|
          message.params[v].casecmp(@arguments[k]) == 0
        end.all?
      end

      def stop?(message)
        collect?(message) && end_replies.include?(message.command)
      end

      def error?(message)
        stop?(message) && error_replies.include?(message.command)
      end
    end
  
    module Configurable
      attr_reader :reply_map

      def initialize
        @reply_map = {}
      end

      def add_reply(*replies, **opts)
        has_end = opts.delete(:has_end) if opts.key? :has_end

        replies.each do |reply|
          @reply_map[reply] = {
            match: {},
            end: has_end && reply == replies.last,
            error: false,
            from: nil
          }.merge(opts)
        end
      end

      def add_end_reply(*replies, **opts)
        add_reply(*replies, **opts.merge(end: true))
      end

      def add_error_reply(*replies, **opts)
        add_reply(*replies, **opts.merge(error: true))
      end
    end
  end
end
