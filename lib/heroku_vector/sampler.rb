
module HerokuVector
  class Sampler
    include HerokuVector::Helper

    attr_reader :capacity, :data

    def initialize(capacity)
      @capacity = capacity
      clear
    end

    def clear
      @data = []
    end

    def full?
      @capacity == size
    end

    def size
      data.size
    end

    def push(value)
      data.push value
      data.shift if size > capacity
    end
    alias_method :<<, :push

    def mean
      return 0 unless size >= 1

      mean_value = data.reduce(:+).to_f / size.to_f
      round_to_one_decimal( mean_value )
    end

    class << self
      def capacity_for_sample_period(period_in_sec)
        case period_in_sec
          when 60;  5         # Last 5 mins (every minute)
          when 10;  2 * 6     # Last 2 mins
          when 5;   2 * 12    # Last 2 mins (every 5s)
          when 1;   2 * 60    # Last 2 mins (every sec)
          else;     100
        end
      end
    end
  end
end