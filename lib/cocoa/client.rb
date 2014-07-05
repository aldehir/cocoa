#!/usr/bin/env ruby
require 'eventmachine'
require 'rainbow'

require 'cocoa/irc'
require 'cocoa/filtered_observable'
require 'cocoa/user_list'
require 'cocoa/channel_list'

module Cocoa
  module Client
    include FilteredObservable
    include IRC::Protocol

    attr_reader :log, :channels, :users, :factory

    def initialize(nickname, user, realname, max_nick_attempts: 3)
      super()

      @max_nick_attempts = max_nick_attempts
      @identity = User.new(self, nickname: nickname, user: user,
                           realname: realname)

      @factory = IRC::CommandFactory.new(self)

      subscribe(:ping, :on_ping)
      subscribe(:topic, :on_topic)
      subscribe(:nick, :on_nick)
      subscribe(:privmsg, :on_privmsg)
      subscribe(:notice, :on_notice)
      subscribe(:join, :on_join)
      subscribe(:part, :on_part)
      subscribe(:kick, :on_kick)
      subscribe(:quit, :on_quit)

      @channels = ChannelList.new(self)
      @users = UserList.new(self)

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
      notify_observers(:topic_change, channel, topic)
    end

    def on_nick(msg)
      old = msg.nickname
      new = msg.params[-1]
      notify_observers(:nick_change, old, new)
    end

    def on_privmsg(msg)
      from = @users[msg.nickname]
      to = msg.params[0]

      if to =~ /\A[#&]/
        to = @channels[to]
      else
        to = @users[to]
      end

      message = strip_formatting(msg.params[-1])
      notify_observers(:message, to, from, message)

      specialized = to.is_a?(Channel) ? :channel_message : :user_message
      puts to
      notify_observers(specialized, to, from, message)
    end

    def on_notice(msg)
      if msg.nickname
        # Notice from user to channel or user
        from = @users[msg.nickname]
        to = msg.params[0]

        if to =~ /\A[#&]/
          to = @channels[to]
        else
          to = @users[to]
        end

        message = strip_formatting(msg.params[-1])
        notify_observers(:notice, to, from, message)

        specialized = to.is_a?(Channel) ? :channel_notice : :user_notice
        notify_observers(specialized, to, from, message)
      else
        # Server notice
        notify_observers(:server_notice, message)
      end
    end

    def on_join(msg)
      user = @users[msg.nickname]
      channel = @channels[msg.params[0]]
      notify_observers(:user_join, channel, user) unless user.me?
    end

    def on_part(msg)
      user = @users[msg.nickname]
      channel = @channels[msg.params[0]]
      message = msg.params.last
      notify_observers(:user_part, channel, user, message)
    end

    def on_quit(msg)
      user = @users[msg.nickname]
      message = msg.params.last
      notify_observers(:user_quit, user, message)
    end

    def on_kick(msg)
      from = @channels[msg.params[0]]
      user = @users[msg.params[1]]
      by = @users[msg.nickname]
      message = msg.params.last

      notify_observers(:user_kick, from, user, by, message)
    end

    def join(channel, deferrable = nil)
      deferrable ||= EventMachine::DefaultDeferrable.new
      message, sequence = @factory.create(:join, channel)

      sequence.callback do |messages|
        channel_obj = Channel.new(self)

        messages.each do |message|
          case message.command
          when :join
            channel_obj.name = message.params.last
          when :rpl_topic
            channel_obj.topic = message.params.last
          when :rpl_namreply
            partial = message.params.last.split().map do |nick|
              /\A(?<prefix>[@+%])?(?<nick>.*)\z/.match(nick)
            end

            partial.each do |matchdata|
              prefix = matchdata['prefix']
              nick = matchdata['nick']

              user = @users[nick]
              unless user
                user = User.new(self, nickname: nick)
                @users.add(user)
              end

              channel_obj.add_user(user, prefix: prefix)
            end
          end
        end

        @channels.add(channel_obj)

        # Send join notification
        notify_observers(:user_join, channel_obj, @identity)

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
      @users << @identity
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

    def strip_formatting(line)
      line.gsub(/([\x0F\x02\x16\x1F]|\x03\d{0,2}(,\d{0,2})?)/, '')
    end

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
