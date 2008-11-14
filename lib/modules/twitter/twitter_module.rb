require File.join(File.dirname(__FILE__), 'twitter_hub')

class TwitterModule
  include Computer::Bot::Module

  def initialize(name, bot, config, logger)
    @bot = bot
    @config = config
    @logger = logger

    @logger.info 'Initializing Twitter module'

    Twitter::Client.configure do |conf|
      conf.protocol = :ssl
      conf.host = 'twitter.com'
      conf.port = 443
      conf.user_agent = @config['user_agent'] || 'ComputerBot'
      conf.application_name = @config['application_name'] || 'ComputerBot'
      conf.application_version = @config['application_version'] || 'v1'
      conf.application_url = @config['application_url'] || 'http://webcracy.org'
      conf.source = @config['source']
    end

    @twitter = TwitterHub.new(@bot, @config)
    register!(name)
  end

  def register!(namespace)
    @bot.add_command(
      :syntax      => 'me',
      :description => 'Returns the username you are using.',
      :regex       => /^me$/,
      :namespace   => namespace,
      :is_public   => false
    ) do |sender, message|
      @bot.deliver(sender, @twitter.me)
      nil
    end      

    @bot.add_command(
      :syntax      => 'say <Your tweet>',
      :description => 'Post a message to Twitter',
      :regex       => /^say\s+.+$/,
      :namespace   => namespace,
      :is_public   => false
    ) do |sender, message|
      @bot.deliver(sender, @twitter.post(message))
      nil
    end

    @bot.add_command(
      :syntax => 'last <0-9>',
      :description => 'Retrieve X latest posts from your timeline (posts from friends)',
      :regex => /^last\s+.+$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      limit = message.to_i
      limit = 20 if limit.zero?

      @bot.deliver(sender, @twitter.friends(limit))
      nil
    end

    @bot.add_command(
      :syntax => 'all',
      :description => 'Retrieve the 20 messages from twitter timeline (posts from friends)',
      :regex => /^all$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      @bot.deliver(sender, @twitter.friends(20))
      nil
    end

    @bot.add_command(
      :syntax => 'trends',
      :description => 'See what people are talking about.',
      :regex => /^trends$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      @bot.deliver(sender, @twitter.trends(sender))
      nil
    end

    @bot.add_command(
      :syntax => 'dm',
      :description => 'Retrieve direct messages sent to you',
      :regex => /^dm$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      @bot.deliver(sender, @twitter.dm)
      nil
    end

    @bot.add_command(
      :syntax => 'user <username> <0-9>',
      :description => 'Retrieve last X twitter messages from given user',
      :regex => /^user\s+.+$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      user = message.split.first.gsub('@', '')
      limit = message.split[1] || 20

      @bot.deliver(sender, @twitter.user(user, limit))
      nil
    end

    @bot.add_command(
      :syntax => 'search <query>',
      :description => 'Search and returns the 5 latest results',
      :regex => /^search\s+.+$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      @bot.deliver(sender, @twitter.query(sender, message))
      nil
    end

    @bot.add_command(
      :syntax => 'replies',
      :description => 'Returns the 5 latest @replies from Twitter Search',
      :regex => /^replies$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      @bot.deliver(sender, @twitter.replies)
      nil
    end

    @bot.add_command(
      :syntax => 'new',
      :description => 'Delivers "unread" twitter messages',
      :regex => /^new$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      @bot.deliver(sender, @twitter.unread)
      nil
    end

    @bot.add_command(
      :syntax => 'live <start|status|stop>',
      :description => 'Delivers new tweets as they come up. Requires start, status or stop instructions.',
      :regex => /^live\s+.+$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      # Live Twitter message delivery happens inside a dedicated thread,
      # so we make a different method call
      @twitter.live(sender, message)
      nil
    end       

    @bot.add_command(
      :syntax => 'track <keyword>',
      :description => 'Delivers new tweets matching keyword search results as they come up.',
      :regex => /^track\s+.+$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      # Live Twitter message delivery happens inside a dedicated thread,
      # so we make a different method call
      @twitter.track(sender, message)
      nil
    end

    @bot.add_command(
      :syntax => 'whois <username>',
      :description => 'Returns whois info for a given username',
      :regex => /^whois\s+.+$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      user = message.split.first.gsub('@', '')
      @bot.deliver(sender, @twitter.whois(user))
      nil
    end       

    @bot.add_command(
      :syntax => 'follow <username>',
      :description => 'Start following a given user.',
      :regex => /^follow\s+.+$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      user = message.split.first.gsub('@', '')
      @bot.deliver(sender, @twitter.follow(user))
      nil
    end

    @bot.add_command(
      :syntax => 'unfollow <username>',
      :description => 'Unfollow a given user.',
      :regex => /^unfollow\s+.+$/,
      :namespace => namespace,
      :is_public => false
    ) do |sender, message|
      user = message.split.first.gsub('@', '')
      @bot.deliver(sender, @twitter.unfollow(user))
      nil
    end
  end
end
