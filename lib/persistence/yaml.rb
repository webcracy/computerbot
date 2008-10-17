require 'rubygems'
require 'yaml'

module Computer
  module Bot
    module Persistence
      class YAML
        include Computer::Bot::Persistence

        def initialize(config)
          @storage = YAML::Store.new(config['path'])
        end

        def write(namespace, key, value)
          @storage.transaction do |store|
            store[key] = value
          end
        end

        def read(namespace, key)
          value = nil
          @storage.transaction do |store|
            value = store[key]
          end

          value
        end
      end
    end
  end
end
