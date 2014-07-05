
module Cocoa
  module FilteredObservable
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
    end

    module ClassMethods
      def attr_observable(**attributes)
        class_eval do
          attributes.each do |attribute, event|
            attr_reader attribute

            define_method("#{attribute}=") do |val|
              old = instance_variable_get("@#{attribute}")
              instance_variable_set("@#{attribute}", val)
              notify_observers(event, self, old)
            end
          end
        end
      end
    end

    module InstanceMethods
      def add_observer(observer, event = nil, &block)
        config = FilteredObservable::Configuration.new

        if event
          single_entry = config.observe(event, &block)
        else
          yield config
        end
        
        @observers ||= []

        index = @observers.index { |x| x[:observer].equal?(observer) }
        if index
          hash = @observers[index]
          config.entries.each do |event, entries|
            hash[:events][event] ||= []
            hash[:events][event] += entries
          end
        else
          @observers << {
            observer: observer,
            events: config.entries
          }
        end

        single_entry if event
      end

      def remove_observer(observer)
        return if @observers.nil?
        @observers.delete_if { |o| o[:observer].equal?(observer) }
      end

      def notify_observers(event, *args)
        return if @observers.nil?
        @observers.each do |observer_hash|
          observer = observer_hash[:observer]
          events = observer_hash[:events]

          next unless events.include? event

          events[event].each do |entry|
            next if entry.filter_by && !entry.filter_by.call(*args)

            if entry.method.is_a? Symbol
              next unless observer.respond_to? entry.method
              observer.send entry.method, event, *args
            else
              entry.method.call(event, *args)
            end
          end
        end
      end
    end

    class Configuration
      attr_reader :entries

      def initialize
        @entries = Hash.new { |h, k| h[k] = [] }
      end

      def observe(event, method = nil, &block)
        entry =
          if block_given?
            Entry.new(event, block)
          else
            Entry.new(event, method)
          end

        @entries[event] << entry
        entry
      end

      class Entry
        attr_accessor :event, :method, :filter_by
        def initialize(event, method)
          @event = event
          @method = method
          @filter_by = nil
        end

        def when(&block)
          @filter_by = block if block_given?
        end
      end
    end
  end
end
