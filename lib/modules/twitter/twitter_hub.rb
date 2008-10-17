# sudo gem install twitter4r
# http://twitter4r.rubyforge.org

require 'rubygems'
require 'twitter'
require 'open-uri'

class TwitterHub
  def initialize(bot, config)
    @twitter = Twitter::Client.new(:login => config['username'],
                                   :password => config['password'])
    @bot = bot
    @username = config['username']
    @namespace = "twitter_#{@username}"
  end

  def me
    "You're logged in as: #{@username}"
  end

  def post(status)
    begin
      posted_status = @twitter.status(:post, status)
    rescue => re
      return "I couldn't post to Twitter, sorry. Please try again. Error was #{re.to_s}."
    end # begin        

    if posted_status 
      return "Status updated: http://twitter.com/#{Twitter_username}/statuses/#{posted_status.id}"
    else 
      return "For no valid reason, I can't be sure this worked. You should check it out: http://twitter.com. Maybe it's a whale."
    end # if posted_status
  end # self.post  
    
  def unread
    unread_since = @bot.persistence.read(@namespace, 'unread')

    timeline = @twitter.timeline_for(:friends,
                                     :since_id => unread_since)

    if timeline.length > 0
      @bot.persistence.write(@namespace, 'unread', timeline.first.id)

      timeline.inject([]) do |result, status|
        result << TwitterHub::Helper.format_status(status)
        result
      end
    else
      'No new messages since your last check'
    end
  end
    
  def live(sender, order)
    case order
    when 'start'
      @twitter_live_thread = Thread.new do 
        @bot.deliver(sender, "Live Twitter feed started at #{Time.now.to_s}")
        loop do
          timeline = @twitterhub_client.timeline_for(:friends, :since_id => @bot.persistence.read(@namespace, 'unread'))

          if timeline.length > 0
            @bot.deliver(sender, "A delivery at #{Time.now.to_s}")
            @bot.persistence.write(@namespace, 'unread', timeline.first.id)

            messages = timeline.inject([]) do |result, status|
              result << TwitterHub::Helper.format_status(status)
              result
            end

            @bot.deliver(sender, messages)
          end # if

          sleep 60
        end # loop
      end # Thread.new
    when 'status'
      if @twitter_live_thread and @twitter_live_thread.alive?
        @bot.deliver(sender, 'The Live feed is running and seems OK. Tell your friends to tweet!')
      else
        @bot.deliver(sender, 'Live Twitter feed not running.')
      end # if
    when 'stop'
      @twitter_live_thread.exit if @twitter_live_thread
      @bot.deliver(sender, 'Live Twitter feed stopped.')
    else
      @bot.deliver(sender, "Command #{order} not recognized")
    end # if
  end # self.live

  def friends(limit)      
    timeline = @twitter.timeline_for(:friends, :count => limit)

    timeline.inject([]) do |result, status|
      result << TwitterHub::Helper.format_status(status)
      result
    end
  end # self.friends
    
  def dm
    dms = @twitter.messages(:received)

    dms[0..4].inject([]) do |result, dm|
      result << TwitterHub::Helper.format_dm(dm)
      result
    end
  end # self.dm
    
  def user(user, limit)
    begin 
      user_test = @twitter.user(user)

      timeline = @twitter.timeline_for(:user, :id => user)
      timeline = timeline.first(limit.to_i) if limit

      timeline.inject([]) do |result, status|
        result << TwitterHub::Helper.format_status(status)
        result
      end
    rescue Twitter::RESTError => re
      "User #{user} has a private profile or does not exist."
    end # begin
  end # self.user

  def query(sender, query)
    original_query = query

    # url encode the query
    query = TwitterHub::Helper.format_query(query)

    begin
      search = JSON.load open("http://search.twitter.com/search.json?q=#{query}")

      if search and search['results'].length > 0
        search['results'].first(5).inject([]) do |result, status|
          result << TwitterHub::Helper.format_search_status_json(status)
          result
        end
      else
        "No results found for query: #{original_query}"
      end # if search.entries...
    rescue 
      return "I couldn't reach the server. Please try again."
    end
  end # self.query
    
  def trends(sender)
    begin
      search = JSON.load open("http://search.twitter.com/trends.json")

      if search and search['trends'].length > 0
        search['trends'].inject([]) do |result, trend|
          result << trend['name']
          result
        end.join(', ')
      else 
        "I didn't find any trends... sorry about that. Try again later."
      end # if search
    rescue
      "I couldn't fetch the trends, sorry. Try again later."
    end # begin
  end # self.trends

  def track(sender, query)
    original_query = query

    case query
    when 'start'
      query = TwitterHub::Helper.format_query(query)

      @track_live_thread = Thread.new do 
        begin
          initial_search = JSON.load open("http://search.twitter.com/search.json?q='#{query}'")
        rescue
          @bot.deliver(sender, "Hmmm, that keyword isn't returning anything.")
        end # begin

        if initial_search  
          @bot.deliver(sender, "Now tracking '#{original_query}' (started at #{Time.now.to_s})")
        end # if initial_ser

        unless initial_search['results'].empty?
          @bot.persistence.write(@namespace, 'track', initial_search['max_id'])
          @bot.deliver(sender, "These were the latest 2 tweets before you started tracking: ")

          messages = initial_search['results'].first(2).inject([]) do |result, status|
            result << TwitterHub::Helper.format_search_status_json(status)
            result
          end

          @bot.deliver(sender, messages)
        else 
          @bot.deliver(sender, "No previous results were found for your query '#{original_query}'. Tracking enabled.")
        end # if initial_search['results']

        loop do
          since_id = @bot.persistence.read(@namespace, 'track')

          begin
            search = JSON.load open("http://search.twitter.com/search.json?q='#{query}'&since_id='#{since_id}'")
          rescue
          end # begin

          if !search['results'].empty? and search['max_id'] > since_id

            @bot.deliver(sender, "New results for #{original_query} at #{Time.now.to_s}")
            @bot.persistence.write(@namespace, search['max_id'])

            messages = search['results'].inject([]) do |result, status|
              result << TwitterHub::Helper.format_search_status_jsjon(status)
              result
            end

            @bot.deliver(sender, messages)
          end # if        

          sleep 60
        end # loop
      end # Thread.new

    when 'status'
      if @track_live_thread and @track_live_thread.alive?
        @bot.deliver(sender, 'The Track feed is running and seems OK. Your keyword must be unpopular :)')
      else
        @bot.deliver(sender, 'Live Track feed not running.')
      end # if
    when 'stop'
      @track_live_thread.exit if @track_live_thread
      @bot.deliver(sender, 'Live Track feed stopped.')
    end # if query
  end # self.track

  def self.replies
    user = Twitter_username
    begin
      search = JSON.load open("http://search.twitter.com/search.json?q='%40#{user}'")
    rescue
      return "I couldn't reach the server, sorry. Please try again."
    end # begin
    if search['results'].length > 0
      messages = Array.new
      search['results'][0..4].each do |status|
        message = TwitterHub::Helper.format_search_status_json(status)
        messages << message
      end # search.entries.each
      return messages 
    else
      return "Sorry, I found no replies to @#{user}."
    end # if search.entries.length
  end # replies
  
  def whois(username)      
    begin
      user = @twitter.user(username)

      messages = Array.new

      messages << "Who is " + username + "? http://twitter.com/#{username}"
      messages << "#{user.name} tweets from #{user.location}. Web: #{user.url}"
      messages << "Bio: #{user.description}"

      tweet = @twitter.timeline_for(:user, :id => username).first.text
      messages << "Last tweet from #{username}: #{tweet}"

      messages << "Use 'twitter.(un)follow #{username}' or 'twitter.user #{username} X' to retrieve X latest msgs."
    rescue Twitter::RESTError => re 
      "User '#{username}' was not found. Please try again."
    end
  end # whois
    
  def follow(username)
    friend = @twitter.user(username)

    begin 
      @twitter.friend(:add, friend.id) 
      "You're now following #{username} -- http://twitter.com/#{username}"
    rescue Twitter::RESTError => re 
      case re.code
      when "403" 
        "You're already following #{username}, so nothing happened just now."
      else  
        'Whooops, a weird thing happened. Please retry. ' + re.to_s
      end # case
    end # begin
  end # follow
    
  def unfollow(username)
    friend = @twitter.user(username)
    
    begin 
      @twitter.friend(:remove, friend.id) 
      "You won't receive #{username}'s updates anymore."      
    rescue Twitter::RESTError => re 
      case re.code
      when "403" 
        "You weren't following #{username}, so nothing new happened."
      else  
        'Whooops, a weird thing happened. Please retry. ' + re.to_s
      end # case
    end # begin
  end # unfollow
    
  module Helper
    extend self

    def format_status(status)
      "#{status.user.screen_name.to_s}: #{status.text.to_s} -- #{self.didwhen(status.created_at)}."
    end # format_status
    
    def format_dm(status)
      "#{status.sender.screen_name.to_s}: #{status.text.to_s} -- #{self.didwhen(status.created_at)}."
    end # self.format_dm
      
    def format_search_status_rss(status)
      "#{status.author.split.first}: #{status.title} -- #{self.didwhen(status.updated)}."
    end # format_search_status_rss
    
    def format_search_status_json(status)
      "#{status['from_user']}: #{status['text']} -- #{self.didwhen(Time.parse(status['created_at']))}."
    end # format_search_status_json
    
    def didwhen(old_time) # stolen from http://snippets.dzone.com/posts/show/5715
      val = Time.now - old_time
       if val < 10 then
         result = 'just a moment ago'
       elsif val < 40  then
         result = 'less than ' + (val * 1.5).to_i.to_s.slice(0,1) + '0 seconds ago'
       elsif val < 60 then
         result = 'less than a minute ago'
       elsif val < 60 * 1.3  then
         result = "1 minute ago"
       elsif val < 60 * 50  then
         result = "#{(val / 60).to_i} minutes ago"
       elsif val < 60  * 60  * 1.4 then
         result = 'about 1 hour ago'
       elsif val < 60  * 60 * (24 / 1.02) then
         result = "about #{(val / 60 / 60 * 1.02).to_i} hours ago"
       else
         result = old_time.strftime("%H:%M %p %B %d, %Y")
       end
      return "#{result}"
    end # self.didwhen
    
    def format_query(query)
      query.gsub(/[^a-zA-Z0-9_\.\-]/n) {|s| sprintf('%%%02x', s[0]) }
    end
  end # Helper
end # TwitterHub
