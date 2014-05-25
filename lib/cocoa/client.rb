#!/usr/bin/env ruby
require 'eventmachine'
require 'rainbow'

require 'cocoa/irc'

module Cocoa
  module Client
    include IRC::Protocol

    attr_reader :log

    def initialize(nickname, user, realname)
      super(nickname, user, realname)

      setup_logger
    end

    def register_succeeded(messages)
      log.info("Successfully registered as nick #{identity.nickname}")
    end

    def register_failed(message)
      log.error("Failed to register: #{message.params.last}")
    end

    def register_timeout
      log.error("Registration timed out")
    end

    def receive_line(line)
      log.info(line)
      super
    rescue Cocoa::IRC::RawMessage::ParseError => e
      log.warn(e.to_s)
    end

    def send_line(line)
      log.info(">>> #{line}")
      super
    end

    private

    def setup_logger
      colors = { 'DEBUG' => :cyan, 'WARN' => :yellow, 'ERROR' => :red,
                 'FATAL' => :red }

      @log = Logger.new(STDOUT)
      @log.level = Logger::DEBUG
      @log.formatter = proc do |severity, datetime, progname, msg|
        formatted_date = datetime.strftime("%I:%M:%S %p")
        severity_abbrev = severity[0]

        color = msg.start_with?('>>>') && :green || colors[severity] || nil
        output = "[#{formatted_date}] [#{severity_abbrev}] #{msg}"
        
        (color && Rainbow(output).color(color) || output) + "\n"
      end
    end
  end
end
