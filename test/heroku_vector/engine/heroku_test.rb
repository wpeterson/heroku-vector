require File.absolute_path File.dirname(__FILE__) + '/../../test_helper'

describe HerokuVector::Engine::Heroku do
  let(:heroku_app_name) { 'app_name' }
  let(:engine) { HerokuVector::Engine::Heroku.new }
  before { HerokuVector.stubs(:heroku_app_name => heroku_app_name) }

  describe '#initialize' do
    it 'should set app name from config' do
      assert_equal heroku_app_name, engine.app
    end

    it 'should instantiate a Heroku API client' do
      assert engine.heroku
    end
  end

  describe '#get_dyno_types' do
    it 'should load dyno definitions from Heroku API' do
      VCR.use_cassette('heroku_dyno_types') do
        dyno_types = engine.get_dyno_types
        dynos_by_name = dyno_types.index_by {|dyno| dyno["name"] }
        assert_equal 1, dynos_by_name['web']['quantity']
        expected_command = "bin/nginx_wrapper bundle exec rainbows -c ./config/rainbows.rb"
        assert_equal expected_command, dynos_by_name['web']['command']
      end
    end
  end

  describe '#scale_dynos' do
    it 'should call Heroku API and issue command' do
      VCR.use_cassette('heroku_scale_dynos') do
        engine.scale_dynos('web', 1)

      end
    end
  end

  describe '#get_dynos_by_name' do
    it 'should index dyno array by name' do
      dynos = [{ 'name' => 'web', 'quantity' => 1 }]
      engine.expects(:get_dyno_types => dynos)

      dynos_by_name = engine.get_dynos_by_name
      assert_equal 1, dynos_by_name['web']['quantity']
    end
  end

  describe '#get_dynos_by_name_cached' do
    it 'should cache calls to get_dynos_by_name' do
      value = 'dynos'
      engine.expects(:get_dynos_by_name => value).once

      time = Time.now
      Timecop.freeze(time) do
        assert_equal value, engine.get_dynos_by_name_cached
        assert_equal value, engine.get_dynos_by_name_cached
        cache_entry = engine.instance_variable_get(:@dynos_by_name)
        assert cache_entry
        assert_equal value, cache_entry.data
        assert_equal time + 60, cache_entry.expires_at
      end
    end

    it 'should get new value when cached value expired' do
      value = 'dynos'
      engine.expects(:get_dynos_by_name => value).twice

      time = Time.now
      Timecop.freeze(time) do
        assert_equal value, engine.get_dynos_by_name_cached
        assert_equal value, engine.get_dynos_by_name_cached
      end
      Timecop.freeze(time+61) do
        assert_equal value, engine.get_dynos_by_name_cached
      end
    end

    describe '#count_for_dyno_name' do
      it 'should lookup dyno count' do
        dynos = { 
          'web' => { 'name' => 'web', 'quantity' => 1 }
        }
        engine.stubs(:get_dynos_by_name_cached => dynos)

        assert_equal 0, engine.count_for_dyno_name('unknown'), 'should return 0 for unknown dyno'
        assert_equal 1, engine.count_for_dyno_name('web'), 'should return dyno quantity from dynos set'
      end
    end
  end
end
