require 'cocoa/irc/commands'

module Cocoa::IRC
  # Represents a raw message that adheres to the Internet Chat Relay: Client
  # Protocol (RFC 2812).
  #
  # Methods are provided to parse raw messages, as well as creating a raw
  # message easily.
  class RawMessage
    Error = Class.new(StandardError)
    ParseError = Class.new(Error)

    PATTERN = /\A
      # Prefix
      (?::(?<prefix>
        (?<nickname>[^!@\s]+)((!(?<user>[^@\s]+))?@(?<host>[^\s]+)) |
        (?<servername>[^\s]+)
      )\s)?

      # Command
      (?<command>[a-zA-Z]+|\d{3})

      # Parameters
      (?:
        \s(?<params>([^\0\s:][^\0\s]*)(\s[^\0\s:][^\0\s]*)*)
      )?

      # Trailing
      (?:\s:(?<trailing>[^\0\r\n]*))?
    \z/x

    attr_reader :servername, :nickname, :user, :host, :command, :params

    def initialize(command, *params, **prefix)
      @command = command
      @params = params
      self.prefix = prefix
    end

    def from_server?
      @servername.nil?
    end

    def from_user?
      @user.nil?
    end

    def prefix
      if @nickname
        suffix = @host ? "@#{@host}" : ''
        suffix.prepend("!#{@user}") if @user && !suffix.empty?
        ":#{@nickname}{suffix}"
      else
        ":#{@servername}" if @servername
      end
    end

    def to_s
      [prefix, Commands.from_sym(@command), format_params].compact.join(' ')
    end

    def self.parse(raw_msg)
      RawMessage::PATTERN.match(raw_msg) do |m|
        params = m[:params].nil? ? [] : m[:params].split
        params << m[:trailing] unless m[:trailing].nil?

        prefix_keys = %i(servername nickname user host)
        prefix = prefix_keys.map { |x| [x, m[x]] }.to_h

        command = Commands.to_sym(m[:command])
        return RawMessage.new(command, *params, **prefix)
      end

      fail ParseError, "Unable to parse: #{raw_msg}"
    rescue Commands::InvalidCommandError
      raise ParseError, "Unable to parse: #{raw_msg}"
    end

    private

    def format_params
      formatted = ''
      params = @params.dup

      unless @params.empty?
        params[-1] = ':' + params[-1]
        formatted = params.join(' ')
      end

      formatted
    end

    def prefix=(details)
      unless details.nil?
        @servername = details.fetch(:servername, nil)
        @nickname = details.fetch(:nickname, nil)
        @user = details.fetch(:user, nil)
        @host = details.fetch(:host, nil)
      end
    end
  end
end
