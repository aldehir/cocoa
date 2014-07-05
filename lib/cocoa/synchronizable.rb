module Cocoa
  module Synchronizable
    def self.included(base)
      base.extend(ClassMethods)
    end

    def synchronized(deferrable = nil, force: false, &block)
      deferrable ||= EventMachine::DefaultDeferrable.new
      deferrable.callback(&block) if block_given?

      # Don't bother resynchronizing if not forced
      if synchronized? && !force
        EventMachine.next_tick { deferrable.succeed(self) }
        return deferrable
      end

      sync_methods = self.class.class_variable_get(:@@sync_attributes).values
      sync_methods.uniq!
      sync_methods.map! { |m| [m, EventMachine::DefaultDeferrable.new] }

      synchronized = 0
      sync_methods.each do |method, d|
        self.send(method).callback do
          synchronized += 1
          deferrable.succeed(self) if synchronized == sync_methods.size
        end
      end

      deferrable
    end
    alias_method :sync, :synchronized

    def synchronized?
      sync_attribs = self.class.class_variable_get(:@@sync_attributes).keys
      values = sync_attribs.map { |k| instance_variable_get("@#{k}") }
      values.all? { |v| !v.nil? }
    end

    module ClassMethods
      def synchronize(*attributes, method:)
        class_eval do
          unless class_variable_defined? :@@sync_attributes 
            class_variable_set(:@@sync_attributes, {})
          end

          attribute_hash = class_variable_get(:@@sync_attributes)
          attribute_hash.merge!(attributes.map { |a| [a, method] }.to_h)
          class_variable_set(:@@sync_attributes, attribute_hash)
        end
      end
    end
  end
end
