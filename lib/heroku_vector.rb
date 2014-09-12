module HerokuVector
  module Engine
  end
  module Source
  end
end

require 'logger'

require 'heroku_vector/helper'

require 'heroku_vector/dyno_scaler'
require 'heroku_vector/process_manager'
require 'heroku_vector/sampler'
require 'heroku_vector/worker'
require 'heroku_vector/version'
require 'heroku_vector/engine/heroku'
require 'heroku_vector/source/new_relic'
require 'heroku_vector/source/sidekiq'

module HerokuVector
  class << self

    def default_logger
      return options[:logger] if options[:logger]

      logger = Logger.new(STDOUT)
      logger.level = options[:log_level]
      logger.formatter = proc do |severity, time, program_name, message|
        "#{time.utc.iso8601(3)} #{severity}: #{message}\n"
      end

      logger
    end

    def options
      @options ||= DEFAULTS.dup
    end

    def options=(opts)
      @options = opts
    end

    def configure
      yield self if block_given?
    end

    def logger
      @logger ||= default_logger
    end

    def logger=(log)
      @logger = log
    end

    def engine
      @engine ||= options[:engine]
    end

    def engine=(engine)
      @engine = engine
    end

    def dyno_scalers
      @dyno_scalers ||= {}
    end

    def dyno_scalers=(dyno_scalers)
      @dyno_scalers = dyno_scalers
    end

    def add_dyno_scaler(name, options={})
      dyno_scalers[name] = options
    end

    def min_scale_time_secs
      @min_scale_time_secs ||= options[:min_scale_time_secs]
    end

    def min_scale_time_secs=(time_secs)
      @min_scale_time_secs = time_secs
    end

    def heroku_app_name
      @heroku_app_name ||= ENV['HEROKU_APP_NAME']
    end

    def heroku_app_name=(app_name)
      @heroku_app_name = app_name
    end

    def newrelic_api_key
      @newrelic_api_key ||= ENV['NEWRELIC_API_KEY']
    end

    def newrelic_api_key=(api_key)
      @newrelic_api_key = api_key
    end

    def newrelic_account_id
      @newrelic_account_id ||= ENV['NEWRELIC_ACCOUNT_ID']
    end

    def newrelic_account_id=(account_id)
      @newrelic_account_id = account_id
    end

    def newrelic_app_id
      @newrelic_app_id ||= ENV['NEWRELIC_APP_ID']
    end

    def newrelic_app_id=(app_id)
      @newrelic_app_id = app_id
    end

    def sidekiq_redis_url
      ENV['REDIS_URL'] || 'redis://127.0.0.1/0'
    end

    def sidekiq_redis_namespace
      ENV['SIDEKIQ_REDIS_NAMESPACE']
    end
  end
end

module HerokuVector
  DEFAULTS = {
    :min_scale_time_secs => 5 * 60, # 5 mins
    :log_level => Logger::INFO,
    :engine => Engine::Heroku.new
  }

end
