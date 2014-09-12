require File.absolute_path File.dirname(__FILE__) + '/../../test_helper'

describe HerokuVector::Source::Sidekiq do

  let(:source) do
    HerokuVector::Source::Sidekiq.new
  end

  describe '#initialize' do
    it 'should configure Sidekiq with redis client' do
      redis = mock('redis')
      source.expects(:build_redis_client => redis)

      Sidekiq.redis {|sidekiq_redis| assert_equal redis, sidekiq_redis }
    end
  end

  describe '#build_redis_client' do
    it 'should use redis passed as option' do
      redis = mock('redis')
      assert_equal redis, source.build_redis_client(redis: redis)
    end

    it 'should build client with url passed as option' do
      redis = source.build_redis_client(redis_url: 'redis://localhost:1111')

      assert_equal 'redis://localhost:1111', redis.client.options[:url]
    end

    it 'should default to redis URL from app config' do
      HerokuVector.expects(:sidekiq_redis_url => 'redis://localhost:2222')
      redis = source.build_redis_client

      assert_equal 'redis://localhost:2222', redis.client.options[:url]
    end

    it 'should use app config namespace' do
      HerokuVector.expects(:sidekiq_redis_namespace => 'sidekiq')
      redis = source.build_redis_client

      assert redis.is_a? Redis::Namespace
      assert_equal 'sidekiq', redis.namespace
    end

    it 'should use option namespace' do
      redis = source.build_redis_client(redis_namespace: 'sidekiq')

      assert redis.is_a? Redis::Namespace
      assert_equal 'sidekiq', redis.namespace
    end
  end

   describe '#busy_workers' do
    let(:sidekiq_processes) do
      [
        {"concurrency"=>10, "queues"=>["default"], "busy"=>1 },
        {"concurrency"=>10, "queues"=>["default"], "busy"=>3 },
      ]
    end

    it 'should sum total busy threads from worker processes' do
      source.expects(:sidekiq_processes => sidekiq_processes)

      assert_equal 4, source.busy_workers
    end
  end

  describe 'source requirements' do
    it 'should implement sample' do
      assert source.respond_to?(:sample)
    end

    it 'should implement unit' do
      assert source.respond_to?(:unit)
    end
  end

end
