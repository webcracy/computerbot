module Computer
  module Bot
    module Persistence
      def initialize(config, logger)
        raise "initialize(config, logger) should be implemented"
      end

      def write(namespace, key, value)
        raise "write(namespace, key, value) should be implemented"
      end
      
      def read(namespace, key)
        raise "read(namespace, key) should be implemented"
      end
    end
  end
end
