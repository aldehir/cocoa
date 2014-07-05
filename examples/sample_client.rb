#!/usr/bin/env ruby
require 'eventmachine'
require 'rainbow'

lib_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include? lib_dir

require 'cocoa'

class SampleClient < EventMachine::Connection
  include Cocoa::Client

  def initialize(queue)
    super("Cocoa", "CocoaRN", "Cocoa IRC Client")

    @queue = queue
    cb = proc do |msg|
      send_line(msg)
      queue.pop &cb
    end

    queue.pop &cb

    subscribe(:error) { EventMachine.stop }
  end

  def register_succeeded(messages)
    super

    join("#Cocoa") do |channel|
      channel.message("Hi there!")
      channel.notice("Hi there!")

      channel.add_observer(self, :message) do |event, to, from, msg|
        log.info("#{from.nickname}[#{to.name}]: #{msg}")
      end
    end

    # EventMachine::Timer.new(10) { quit("Session over") }
  end

  def register_failed(message)
    super
    EventMachine.stop
  end
end

module KeyboardHandler
  include EventMachine::Protocols::LineText2

  attr_reader :queue

  def initialize(q)
    @queue = q
  end

  def receive_line(line)
    @queue.push(line)
  end
end

EventMachine.run do
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }

  queue = EventMachine::Queue.new

  EventMachine.connect('localhost', 6667, SampleClient, queue)
  EventMachine.open_keyboard(KeyboardHandler, queue)
end
