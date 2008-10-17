require 'rubygems'
require 'logger'
require 'yaml'

  # Uses the jabber_bot.rb lib directly instead of the rubygem
require File.dirname(__FILE__) + '/jabber_bot.rb'

  # All plugins are loaded here.
require File.dirname(__FILE__) + '/modules/twitta.rb'

module Computer
  class Bot
    def initialize
      # Initialize Jabber configuration
      @config = YAML::load(IO::read(File.dirname(__FILE__) + "/config/#{ENV_SET}.yml"))
          
      @@bot = Jabber::Bot.new(
        :jabber_id => @config['jabber']['username'], 
        :password  => @config['jabber']['password'], 
        :master    => @config['jabber']['master'],
        :presence => :chat,
        :status => @config['jabber']['status'],
        :resource => 'Bot',
        :is_public => false,
        :verbose => true,
        :verbose_level => Logger::INFO
      )
      
      load_commands

      # Register twitter module
      TwitterHub.register!(@@bot)
      
      @@bot.connect
    end

    def deliver(sender, message)
      self.deliver(sender, message)
    end
    
    def self.deliver(sender, message)
      if message.is_a?(Array)
        message.each { |message| @@bot.deliver(sender, message)}
      else
        @@bot.deliver(sender, message)
      end
    end
  
    def load_commands
      @@bot.add_command(
        :syntax      => 'ping',
        :description => 'Returns a pong and a timestamp',
        :regex       => /^ping$/,
        :is_public   => false
      ) do
        "Pong! (#{Time.now})"
      end
         
      @@bot.add_command(
        :syntax      => 'bye',
        :description => 'Swiftly disconnects the bot',
        :regex       => /^bye$/,
        :is_public   => false
      ) do |sender, message|
        execute_bye_command(sender, message)
      nil
      end    
    end # load_commands
    
    def execute_bye_command(sender,message)
      deliver(sender, 'Bye bye.')
      @@bot.disconnect
      exit
    end  
  end # Bot 
end # Computer 

Computer::Bot.new # executes everything when this file is called by computerbot.rb. You will never create another Bot object :)
