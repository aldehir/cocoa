#!/usr/bin/env ruby
require 'eventmachine'
require 'rainbow'

lib_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include? lib_dir

require 'cocoa'


class SampleClient < EventMachine::Connection
  include Cocoa::IRC::Protocol

  def initialize(log, queue)
    super("Cocoa", "Cocoa", "Cocoa IRC Client")
    @log = log

    @queue = queue
    cb = proc do |msg|
      send_line(msg)
      queue.pop &cb
    end

    queue.pop &cb
  end

  def receive_line(line)
    @log.info(line)
    super
  rescue Cocoa::IRC::RawMessage::ParseError => e
    @log.warn(e.to_s)
  end

  def send_line(line)
    @log.info(">>> #{line}")
    super
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

  log = Logger.new(STDOUT)
  log.level = Logger::DEBUG
  log.formatter = proc do |severity, datetime, progname, msg|
    formatted_date = datetime.strftime("%I:%M:%S %p")
    severity_abbrev = severity[0]

    output = "[#{formatted_date}] [#{severity_abbrev}] #{msg}"

    output = 
      if msg.start_with? '>>>'
        Rainbow(output).green
      elsif severity == 'WARN'
        Rainbow(output).yellow
      else
        output
      end

    output + "\n"
  end

  queue = EventMachine::Queue.new

  EventMachine.connect('localhost', 6667, SampleClient, log, queue)
  EventMachine.open_keyboard(KeyboardHandler, queue)
end
