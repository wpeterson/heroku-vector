require 'eventmachine'

module HerokuVector
  class Worker
    include HerokuVector::Helper

    attr_accessor :options, :dyno_scalers, :engine

    def initialize(options={})
      @options = options
      @dyno_scalers = []
    end

    def run
      validate_environment

      if options[:config]
        if File.exist?(options[:config])
          logger.info "Loading config from '#{options[:config]}'"
          load options[:config]
        else
          logger.fatal "No config found at '#{options[:config]}'"
          logger.info "You can copy config.rb.example => config.rb to get started"
          logger.info "OR run heroku_vector -c /path/to/your/config.rb"
          logger.info "Just Starting? Test your Source config with sampler mode: heroku_vector -s"
          exit 1
        end
      end

      load_dyno_scalers

      EM.run do
        dyno_scalers.each do |scaler|
          EM::PeriodicTimer.new(scaler.period) do
            scaler.run
          end
        end
      end
    end

    def load_dyno_scalers
      HerokuVector.dyno_scalers.each do |scaler_def|
        name, options = scaler_def
        logger.info "Loading Scaler: #{name}, #{options.inspect}"

        @dyno_scalers << DynoScaler.new(name, options)
      end
    end

    def validate_environment
      raise "Heroku API: HEROKU_API_KEY not set!" unless ENV['HEROKU_API_KEY']
      unless HerokuVector.heroku_app_name
        raise "Heroku API: app name not configured!  Set HEROKU_APP_NAME or config."
      end
    end

  end
end
