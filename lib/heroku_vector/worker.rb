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
      if options[:config]
        if File.exist?(options[:config])
          logger.info "Loading config from '#{options[:config]}'"
        else
          logger.warn "No config found at '#{options[:config]}'"
        end

        load options[:config]
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

  end
end
