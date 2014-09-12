module HerokuVector
  class DynoScaler
    include HerokuVector::Helper

    MIN_SCALE_TIME_DELTA_SEC = 5 * 60 # 5 mins

    attr_accessor :source, :last_scale_time
    attr_reader :name,
      :sampler, :period, :min_value, :max_value,
      :min_dynos, :max_dynos,
      :engine, :scale_up_by, :scale_down_by

    def initialize(name, options={})
      @name = name
      @period = options[:period] || 60 # 1 min
      sample_size = options[:sample_size] || Sampler.capacity_for_sample_period(@period)
      @sampler = Sampler.new( sample_size )
      @min_dynos = options[:min_dynos] || 2
      @max_dynos = options[:max_dynos] || 10
      @min_value = options[:min_value] || raise("DynoScaler: min_value required")
      @max_value = options[:max_value] || raise("DynoScaler: max_value required")

      @scale_up_by = options[:scale_up_by] || 1
      @scale_down_by = options[:scale_down_by] || 1
      @source = load_data_source(options)
      @engine = options[:engine] || Engine::Heroku.new
    end

    def load_data_source(options)
      source = options[:source]

      if source.is_a?(Class)
        @source = source.new(options)
      else
        begin
          clazz = HerokuVector::Source.const_get(source)
          @source = clazz.new(options)
        rescue
          raise "DynoScaler: Invalid source class '#{source}'"
        end
      end
    end

    def reset
      sampler.clear
      @last_scale_time = nil
    end

    def run
      begin
        collect_sample
        return unless enough_samples?
        return if scaling_too_soon?

        evaluate_and_scale
      rescue => e
        logger.error "#{self.name} worker.run(): #{e}"
      end
    end

    def evaluate_and_scale
      num_dynos = current_size
      total_min = min_value * num_dynos
      total_max = max_value * num_dynos
      value = current_value

      logger.debug "#{self.name}: #{num_dynos} dynos - #{value} #{display_unit}"
      if value < total_min
        unless num_dynos <= min_dynos
          logger.info "#{self.name}: #{num_dynos} dynos - #{value} #{display_unit} below #{total_min} - scaling down"
        end
        # Always scale down one at a time
        new_amount = num_dynos - scale_down_by
        scale_dynos(num_dynos, new_amount)
      elsif value > total_max
        unless num_dynos >= max_dynos
          logger.info "#{self.name}: #{num_dynos} dynos - #{value} #{display_unit} above #{total_max} - scaling up"
        end
        # Scale up to N new dynos
        new_amount = num_dynos + scale_up_by
        scale_dynos(num_dynos, new_amount)
      end
    end

    def current_value
      sampler.mean
    end

    def collect_sample
      sampler << source.sample
    end

    def current_size
      engine.count_for_dyno_name(self.name)
    end

    def scale_dynos(current_amount, new_amount)
      new_amount = normalize_dyno_increment(new_amount)
      return if current_amount == new_amount

      record_last_scale_event

      engine.scale_dynos(self.name, new_amount)
    end

    def normalize_dyno_increment(amount)
      [
        [amount, max_dynos].min,
        min_dynos
      ].max
    end

    def record_last_scale_event
      @last_scale_time = Time.now
    end

    def enough_samples?
      sampler.full?
    end

    def scaling_too_soon?
      return false unless last_scale_time
      scale_delta = Time.now - last_scale_time

      MIN_SCALE_TIME_DELTA_SEC >= scale_delta
    end

    def display_unit
      source.unit rescue 'units'
    end

  end
end
