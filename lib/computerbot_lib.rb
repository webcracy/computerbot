require 'rubygems'
require 'logger'
require 'yaml'
require 'eventmachine'

$LOAD_PATH.unshift File.dirname(__FILE__)

require 'computer_bot_persistence'
require 'computer_bot_module'
# Uses the jabber_bot.rb lib directly instead of the rubygem
require File.dirname(__FILE__) + '/jabber_bot.rb'

Thread.abort_on_exception = true # helps debugging threads

module Computer
  module Bot
    class Base
      attr_reader :persistence

      def initialize
        # Loads the config file
        @config = YAML::load(IO::read(File.dirname(__FILE__) + "/config/#{ENV_SET}.yml"))

        # Configure logger
        if @config['general']['verbose']
          @logger = Logger.new(STDERR)
        else
          @logger = Logger.new('/dev/null')
        end
        @logger.level = Logger::INFO # XXX: this should be configurable on yaml

        # Initialize Persistence configuration
        configure_persistence(@config['general']['persistence'])
            
        # Initializes the Jabber bot
        @bot = Jabber::Bot.new(
          :jabber_id => @config['bot']['username'], 
          :password  => @config['bot']['password'], 
          :master    => @config['bot']['master'],
          :presence  => @config['bot']['presence'] ? @config['bot']['presence'].to_sym : :chat,
          :status    => @config['bot']['status'],
          :resource  => @config['bot']['resource'] || 'Bot',
          :is_public => @config['bot']['is_public'] || false,
          :logger    => @logger
        )
        
        # Loads default commands
        load_commands!

        # Register each module on the config
        configure_modules(@config['modules'])
        
        # Start the all things up
        EventMachine::run {
          @operation = proc do
            @bot.connect
          end

          @callback = proc do
            puts "The end :-)"
          end

          EventMachine::defer(@operation, @callback)
        }
      end

      def add_command(*args, &callback)
        @bot.add_command(*args, &callback)
      end

      def deliver(sender, message)
        if message.is_a?(Array)
          message.each { |message| @bot.deliver(sender, message)}
        else
          @bot.deliver(sender, message)
        end
      end
  
      def load_commands!
        @bot.add_command(
          :syntax      => 'ping',
          :description => 'Returns a pong and a timestamp',
          :regex       => /^ping$/,
          :is_public   => false
        ) do
          "Pong! (#{Time.now})"
        end
           
        @bot.add_command(
          :syntax      => 'bye',
          :description => 'Swiftly disconnects the bot',
          :regex       => /^bye$/,
          :is_public   => false
        ) do |sender, message| execute_bye_command(sender, message)
        nil
        end    
      end # load_commands
      
      def execute_bye_command(sender,message)
        deliver(sender, 'Bye bye.')
        @bot.disconnect
        exit
      end

      def register_periodic_event(interval, &block)
        PeriodicEvent.new(interval, &block)
      end

      private
      def configure_persistence(config)
        unless config['class']
          @logger.fatal "You need to specify a persistence class on your config"
          exit
        end

        file = config['file']
        klass = config['class']

        begin
          eval "require '#{file}'"
          @persistence = (eval klass)
          @persistence = @persistence.new(config['config'], @logger)
        rescue LoadError => e
          @logger.fatal "Couldn't find #{file} on the current path"
          raise e
        rescue NameError => e
          @logger.fatal "Couldn't instanciate #{klass}. Maybe it's not defined in #{file}"
          raise e
        end
      end # configure_persistence

      def configure_modules(config)
        config.each do |mod|
          name = mod['name']
          file = mod['file']
          klass = mod['class']

          begin
            eval "require '#{file}'"
            instance = (eval klass)
            instance = instance.new(name, self, mod['config'], @logger)
          rescue LoadError => e
            @logger.fatal "Couldn't find #{file} on the current path"
            raise e
          rescue NameError => e
            @logger.fatal "Couldn't instanciate #{klass}. Maybe it's not defined in #{file}"
            raise e
          end
        end
      end

      class PeriodicEvent < EventMachine::PeriodicTimer
        def initialize(interval, &block)
          super(interval)

          @operation = proc do
            block.call unless @cancelled
          end

          @callback = proc do
            schedule unless @cancelled
          end
        end

        def fire
          EventMachine::defer(@operation, @callback)
        end
      end
    end # Base
  end # Bot 
end # Computer 

Computer::Bot::Base.new # executes everything when this file is called by computerbot.rb. You will never create another Bot object :)

EventMachine.run { }
