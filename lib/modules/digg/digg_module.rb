require File.join(File.dirname(__FILE__), 'digg_hub')

class DiggModule
  include Computer::Bot::Module

  def initialize(name, bot, config, logger)
    @bot = bot
    @config = config
    @logger = logger

    @logger.info 'Initializing Digg module'

    @digg = DiggHub.new(@bot, @config)
    register!(name)
  end

  def register!(namespace)
    @bot.add_command(
      :syntax      => 'top <limit>?',
      :description => 'Returns the n (default 3) latest top stories.',
      :regex       => /^top(\s+\d+)?$/,
      :namespace   => namespace,
      :is_public   => false
    ) do |sender, message|
      limit = message.to_i
      limit = 3 if limit.zero?

      @bot.deliver(sender, @digg.top(limit))
      nil
    end

    @bot.add_command(
      :syntax      => 'topic <keyword> <limit>?',
      :description => 'Returns the n (default 3) top stories about the topic',
      :regex     => /^topic\s+.+(\s+\d+)?$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      parts = message.split
      topic = parts[0]
      limit = parts[1].to_i if parts.length > 1
      limit = 3 if limit.nil? || limit.zero?

      @bot.deliver(sender, @digg.topic(topic, limit))
      nil
    end

    @bot.add_command(
      :syntax      => 'track <topic>|status|stop',
      :description => 'Tracks live the diggs about a topic',
      :regex       => /^track\s+.+$/,
      :namespace   => namespace,
      :is_public   => false
    ) do |sender, message|
      @digg.track(sender, message)
      nil
    end
  end
end
