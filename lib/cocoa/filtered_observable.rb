
module Cocoa
  module FilteredObservable
    def initialize
      @observers = []
    end

    def add_observer(observer)
      config = Configuration.new
      yield config
    
      @observers << {
        observer: observer,
        events: config.entries
      }
    end

    def remove_observer(observer)
      @observers.delete_if { |o| o[:observer].equal?(observer) }
    end

    def notify_observers(event, *args)
      @observers.each do |observer_hash|
        observer = observer_hash[:observer]
        events = observer_hash[:events]

        next unless events.include? event

        events[event].each do |entry|
          next unless observer.respond_to? entry.method
          next if entry.filter_by && !entry.filter_by.call(*args)

          observer.send entry.method, event, *args
        end
      end
    end

    class Configuration
      attr_reader :entries

      def initialize
        @entries = Hash.new { |h, k| h[k] = [] }
      end

      def observe(event, method, &block)
        entry = Entry.new(event, method)
        entry.when(&block) if block_given?

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
