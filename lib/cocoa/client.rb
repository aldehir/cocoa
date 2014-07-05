#!/usr/bin/env ruby
require 'eventmachine'
require 'rainbow'

require 'cocoa/irc'
require 'cocoa/filtered_observable'
require 'cocoa/builders/channel_builder'

module Cocoa
  module Client
    include FilteredObservable
    include IRC::Protocol

    attr_reader :log, :channels, :users, :factory

    def initialize(nickname, user, realname, max_nick_attempts: 3)
      super()

      @max_nick_attempts = max_nick_attempts
      @identity = OpenStruct.new(
        nickname: nickname,
        user: user,
        realname: realname
      )

      @factory = IRC::CommandFactory.new(self)

      subscribe(:ping, :on_ping)
      subscribe(:topic, :on_topic)

      @channels = []
      @users = []

      setup_logger
    end

    def connection_completed
      # Initiate registration
      register
    end

    def on_ping(msg)
      pong = IRC::RawMessage.new(:pong, *msg.params)
      send_message(pong)
    end

    def on_topic(msg)
      channel, topic = msg.params
      log.info(topic)
      notify_observers(:topic_changed, channel, topic)
    end

    def join(channel, deferrable = nil)
      deferrable ||= EventMachine::DefaultDeferrable.new
      message, sequence = @factory.create(:join, channel)

      sequence.callback do |messages|
        builder = Builders::ChannelBuilder.new(self)
        builder.build(messages)

        channel_obj = builder.result

        # Call success on the deferrable
        deferrable.succeed(channel_obj)
      end

      sequence.errback do |messages|
        # TODO: pass to deferrable
      end

      sequence.timeout_callback do
        # TODO: pass to deferrable
      end

      command(message, sequence)
      deferrable
    end

    def whois(nickname, deferrable = nil)
      deferrable ||= EventMachine::DefaultDeferrable.new
      message, sequence = @factory.create(:whois, nickname)

      sequence.callback do |messages|
        nickname, user, host, realname = nil

        messages.each do |message|
          case message.command
          when :rpl_whoisuser
            nickname, user, host = message.params[1..3]
            realname = message.params[-1]
          end
        end

        notify_observers(:whois_reply, nickname, user, host, realname)
        deferrable.succeed(nickname, user, host, realname)
      end

      sequence.errback do |messages|
        # TODO: pass to deferrable
      end

      sequence.timeout_callback do
        # TODO: pass to deferrable
      end

      command(message, sequence)
      deferrable
    end


    def register(error = nil)
      @nick_attempts = 0 if error.nil?
      @nick_attempts += 1

      if error
        handle = [:err_nickcollision, :err_nicknameinuse]
        return register_failed(error) unless handle.include? error.command
        return register_failed(error) if @nick_attempts > @max_nick_attempts

        @identity_nickname += '_'
      end

      messages, sequence = @factory.create(:nick_user, @identity.nickname,
                                           @identity.user, @identity.realname)

      # Only send the nick message if we have an error
      messages = messages[0] if error

      # Set callbacks
      sequence.callback(&method(:register_succeeded))
      sequence.errback(&method(:register))
      sequence.timeout_callback(&method(:register_timeout))

      command(messages, sequence)
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
    rescue Exception => e
      log.error("Error occurred with: #{line}")
      log.error("    #{e.to_s}")
      e.backtrace.each { |l| log.error("    #{l}") }
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
