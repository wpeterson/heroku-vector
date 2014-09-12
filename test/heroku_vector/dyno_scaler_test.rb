require File.absolute_path File.dirname(__FILE__) + '/../test_helper'

describe HerokuVector::DynoScaler do
  TestSource = Struct.new(:sample)

  let(:dyno_name) { 'web' }
  let(:mock_heroku) { mock('heroku') }
  let(:source) { HerokuVector::Source::NewRelic }

  let(:options) do
    {
      :source => source,
      :period => 60,
      :sample_size => 10,
      :min_dynos => 1,
      :max_dynos => 4,
      :min_value => 3000,
      :max_value => 5000,
      :engine => mock_heroku
    }
  end

  describe '#initialize' do
    it 'should assign values' do
      scaler = HerokuVector::DynoScaler.new(dyno_name, options)

      assert_equal dyno_name, scaler.name
      assert_equal options[:source], scaler.source.class
      assert_equal options[:period], scaler.period
      assert_equal options[:sample_size], scaler.sampler.capacity
      assert_equal options[:min_dynos], scaler.min_dynos
      assert_equal options[:max_dynos], scaler.max_dynos
      assert_equal options[:min_value], scaler.min_value
      assert_equal options[:max_value], scaler.max_value
      assert_equal mock_heroku, scaler.engine
      assert scaler.sampler
    end

    it 'should set default values' do
      scaler = HerokuVector::DynoScaler.new(dyno_name, {
        :min_value => 100,
        :max_value => 200,
        :source => source
      })

      assert_equal 60,  scaler.period
      assert_equal 5,   scaler.sampler.capacity
      assert_equal 2,   scaler.min_dynos
      assert_equal 10,  scaler.max_dynos
      assert_equal 1,   scaler.scale_up_by
      assert_equal 1,   scaler.scale_down_by

      assert scaler.sampler
      assert_equal HerokuVector::Engine::Heroku, scaler.engine.class
    end

    it 'should require min/max values' do
      assert_raises(RuntimeError) do
        scaler = HerokuVector::DynoScaler.new(dyno_name, options.merge(:min_value => nil))
      end
      assert_raises(RuntimeError) do
        scaler = HerokuVector::DynoScaler.new(dyno_name, options.merge(:max_value => nil))
      end
    end

    it 'should instantiate source class instance' do
      clazz = 'NewRelic'
      scaler = HerokuVector::DynoScaler.new(dyno_name, options.merge(:source => clazz) )
      assert_equal "HerokuVector::Source::#{clazz}", scaler.source.class.name

      assert_raises(RuntimeError) do
        scaler = HerokuVector::DynoScaler.new(dyno_name, options.merge(:source => 'invalid_class'))
      end
    end
  end

  describe '#run' do
    let (:scaler) do
      scaler = HerokuVector::DynoScaler.new(dyno_name, options)
      scaler.source = TestSource.new(1)
      scaler
    end

    it 'should collect a new sample' do
      scaler.expects(:collect_sample)

      scaler.run
    end

    it 'should not evaluate scale until enough samples' do
      scaler.stubs(:enough_samples? => false)
      scaler.expects(:evaluate_and_scale).never

      scaler.run
    end

    it 'should not evaluate scale if scaled recently' do
      scaler.stubs(:enough_samples? => true)
      scaler.stubs(:scaling_too_soon? => true)

      scaler.expects(:evaluate_and_scale).never

      scaler.run
    end

    it 'should evaluate_and_scale w/ enough samples' do
      scaler.stubs(:enough_samples? => true)
      scaler.stubs(:scaling_too_soon? => false)

      scaler.expects(:evaluate_and_scale)

      scaler.run
    end
  end

  describe '#reset' do
    let (:scaler) do
      scaler = HerokuVector::DynoScaler.new(dyno_name, options)
      scaler.source = TestSource.new(1)
      scaler
    end

    it 'should reset sampler' do
      assert_equal 0, scaler.sampler.size
      scaler.collect_sample
      assert_equal 1, scaler.sampler.size

      scaler.reset

      assert_equal 0, scaler.sampler.size
    end

    it 'should reset last_scale_time' do
      assert_equal nil, scaler.last_scale_time
      scaler.record_last_scale_event
      assert scaler.last_scale_time

      scaler.reset

      assert_equal nil, scaler.last_scale_time
    end
  end

  describe '#evaluate_and_scale' do
    let (:scaler) do
      scaler = HerokuVector::DynoScaler.new(dyno_name, options)
      scaler.source = TestSource.new(1)
      scaler.reset
      scaler
    end

    it 'should not scale dynos inside min/max range' do
      scaler.stubs(:current_size => 1)
      scaler.source = TestSource.new(scaler.min_value + 1)
      scaler.collect_sample

      scaler.expects(:scale_dynos).never

      scaler.evaluate_and_scale
    end

    it 'should scale down dynos below min_value' do
      scaler.stubs(:current_size => 2)
      scaler.source = TestSource.new(scaler.min_value + 1)
      scaler.collect_sample

      scaler.expects(:scale_dynos).with(2, 1)

      scaler.evaluate_and_scale
    end

    it 'should scale up dynos above max_value' do
      scaler.stubs(:current_size => 1)
      scaler.source = TestSource.new(scaler.max_value + 1)
      scaler.collect_sample

      scaler.expects(:scale_dynos).with(1, 2)

      scaler.evaluate_and_scale
    end
  end

  describe '#scale_dynos' do
    let (:scaler) do
      scaler = HerokuVector::DynoScaler.new(dyno_name, options)
    end

    it 'should not scale if amount is the same' do
      mock_heroku.expects(:scale_dynos).never

      scaler.scale_dynos(1, 1)
      scaler.scale_dynos(2, 2)
      scaler.scale_dynos(3, 3)
      scaler.scale_dynos(4, 4)
    end

    it 'should not scale below min_dynos' do
      mock_heroku.expects(:scale_dynos).never

      scaler.scale_dynos(1, 0)
    end

    it 'should not scale above max_dynos' do
      mock_heroku.expects(:scale_dynos).never

      scaler.scale_dynos(4, 5)
    end

    it 'should scale within min/max' do
      mock_heroku.expects(:scale_dynos).with(scaler.name, 2)

      scaler.scale_dynos(1, 2)
    end
  end

  describe '#scaling_too_soon?' do
    let (:scaler) do
      scaler = HerokuVector::DynoScaler.new(dyno_name, options)
    end

    it 'should not be too soon w/out last_scale_time' do
      assert_equal nil, scaler.last_scale_time
      assert_equal false, scaler.scaling_too_soon?
    end

    it 'should be too soon near last_scale_time' do
      scaler.last_scale_time = Time.now

      assert_equal true, scaler.scaling_too_soon?
    end

    it 'should not be too soon after last_scale_time' do
      threshold = HerokuVector::DynoScaler::MIN_SCALE_TIME_DELTA_SEC
      scaler.last_scale_time = Time.now - threshold - 1

      assert_equal false, scaler.scaling_too_soon?
    end
  end

end
