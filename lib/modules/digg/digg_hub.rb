# sudo gem install dfg59-diggr

require 'rubygems'
require 'diggr'

class DiggHub
  def initialize(bot, config)
    @diggr = Diggr::API.new
    @bot = bot
    @namespace = "digg"
  end

  def top(limit)
    stories = @diggr.stories.top.options(:count => limit)
    stories.inject([]) do |result, story|
      result << "#{story.title} (#{story.user.name})"
      result << "\\--> #{story.href}"
      result
    end
  end
  
  def topic(topic, limit)
    stories = @diggr.stories.topic.send(topic).top.options(:count => limit)
    stories.inject([]) do |result, story|
      result << "#{story.title} (#{story.user.name})"
      result << "\\--> #{story.href}"
      result
    end
  end

  def track(sender, topic)
    if topic != 'status' && topic != 'stop'
      @bot.deliver(sender, "Live Digg feed started at #{Time.now.to_s}")
      @live_track = @bot.register_periodic_event(10) do
        since_id = @bot.persistence.read(@namespace, 'track')
        stories = @diggr.stories.topic.send(topic).top.fetch

        flagged = false
        stories.delete_if do |story|
          if flagged || story.id.to_i == since_id.to_i
            flagged = true
            true
          else
            false
          end
        end

        unless stories.empty?
          @bot.persistence.write(@namespace, 'track', stories.first.id)

          result = stories.inject([]) do |result, story|
            result << "#{story.title} (#{story.user.name})"
            result << "\\--> #{story.href}"
          end

          @bot.deliver(sender, result)
        end
      end
    else

    case topic
      when 'status'
        if @live_track
          @bot.deliver(sender, 'The live Digg feed is running and seems OK. Go Digg some news!')
        else
          @bot.deliver(sender, 'Live Digg feed not running.')
        end
      when 'stop'
        @live_track.cancel if @live_track
        @live_track = nil
        @bot.deliver(sender, 'Live Digg feed stopped.')
      else
        @bot.deliver(sender, "Command #{topic} not recognized")
      end
    end
  end
end
