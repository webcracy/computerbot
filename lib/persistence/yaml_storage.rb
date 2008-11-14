require 'rubygems'
require 'yaml/store'

class YAMLStorage
  include Computer::Bot::Persistence

  def initialize(config, logger)
    @logger = logger

    @storage = YAML::Store.new(config['database'])
    @logger.info "YAML Storage initialized"
  end

  def write(namespace, key, value)
    key = get_key namespace, key
    @logger.info "[YAML] Writing #{key} -> #{value}"

    @storage.transaction do |store|
      store[key] = value
    end
  end

  def read(namespace, key)
    key = get_key namespace, key
    @logger.info "[YAML] Reading #{key}"

    @storage.transaction do |store|
      store[key]
    end
  end

  private
  def get_key(namespace, key)
    "#{namespace}_#{key}"
  end
end
