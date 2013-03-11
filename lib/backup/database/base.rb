# encoding: utf-8

module Backup
  module Database
    class Base
      include Backup::CLI::Helpers
      include Backup::Configuration::Helpers

      ##
      # Creates a new instance of the MongoDB database object
      # * Called using super(model) from subclasses *
      def initialize(model)
        @model = model
        load_defaults!
      end

      ##
      # Super method for all child (database) objects. Every database object's #perform!
      # method should call #super before anything else to prepare
      def perform!
        prepare!
        log!
      end

      private

      ##
      # Defines the @dump_path and ensures it exists by creating it
      def prepare!
        @dump_path = File.join(
          Config.tmp_path,
          @model.trigger,
          'databases',
          self.class.name.split('::').last
        )
        FileUtils.mkdir_p(@dump_path)
      end

      ##
      # Return the database name, with Backup namespace removed
      def database_name
        self.class.to_s.sub('Backup::', '')
      end

      ##
      # Logs a message to the console and log file to inform
      # the client that Backup is dumping the database
      def log!
        Logger.message "#{ database_name } started dumping and archiving '#{ name }'."
      end
    end
  end
end
