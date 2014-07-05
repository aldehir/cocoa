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

    deferrable = join("#Cocoa")
    deferrable.callback do |channel|
      channel.message("Hi there!")
      channel.notice("Hi there!")
      log.info("Callback called")

      channel.users.each do |user|
        log.info("User (unsync): #{user.nickname} #{user.user} #{user.host} #{user.realname}")

        user.synchronized do
          log.info("User (sync): #{user.nickname} #{user.user} #{user.host} #{user.realname}")
          log.info("Sync'd?: #{user.synchronized?}")

          user.synchronized do
            log.info("User (sync): #{user.nickname} #{user.user} #{user.host} #{user.realname}")
            log.info("Sync'd?: #{user.synchronized?}")
          end
        end
      end
    end

    join("#Cocoa2")

    #join("#Cocoa") do |messages|
    #  users = messages.select {
    #    |m| m.command == :rpl_namreply
    #  }.flat_map { |m| m.params.last.split() }
    #  topic_msg = messages.find { |m| m.command == :rpl_topic }
    #  topic = (topic_msg && topic_msg.params.last) || ''

    #  @log.info("Joined #Cocoa, users: " + users.join(', '))
    #  @log.info("Topic: #{topic}")
    #end

    #errback = proc { |m| @log.error("Join failed: " + m.params.last) }
    #join("#passworded", errback: errback) do |messages|
    #  @log.info("Join successful")
    #end

    #join("#partme") do |_|
    #  @log.info("Joined #partme")
    #  part("#partme") do |_|
    #    @log.info("Parted from #partme")
    #  end
    #end

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
