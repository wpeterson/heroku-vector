require 'redis'
require 'redis-namespace'
require 'sidekiq'
require 'sidekiq/api'

module HerokuVector::Source
  class Sidekiq
    def initialize(options={})
      configure_sidekiq_client(options)
    end

    def configure_sidekiq_client(options={})
      ::Sidekiq.configure_client do |config|
        pool_options = { :size => 3, :timeout => 10 }
        config.redis = ConnectionPool.new(pool_options) { build_redis_client(options) }
      end
    end

    def build_redis_client(options={})
      return options[:redis] if options[:redis]

      connection = Redis.new({
        url: options[:redis_url] || HerokuVector.sidekiq_redis_url,
        timeout: 60
      })

      namespace = options[:redis_namespace] || HerokuVector.sidekiq_redis_namespace
      if namespace
        return ::Redis::Namespace.new(namespace, redis: connection)
      else
        return connection
      end
    end

    def sidekiq_processes
      ::Sidekiq::ProcessSet.new
    end

    def busy_workers
      sidekiq_processes.reduce(0) {|i, process| i + process['busy'].to_i }
    end
    alias_method :sample, :busy_workers

    def unit
      'busy threads'
    end

  end
end
