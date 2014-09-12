require 'heroku-api'

module HerokuVector::Engine
  class Heroku
    include HerokuVector::Helper

    CacheEntry = Struct.new(:data, :expires_at)

    attr_accessor :app, :heroku

    def initialize(options={})
      options = { app: HerokuVector.heroku_app_name }.merge(options)

      @app = options[:app]
      @heroku = ::Heroku::API.new
    end

    def get_dynos_by_name_cached
      if @dynos_by_name && @dynos_by_name.expires_at > Time.now
        return @dynos_by_name.data
      end

      @dynos_by_name = begin
        expires_at = Time.now + 60 # 1 min from now
        CacheEntry.new(get_dynos_by_name, expires_at)
      rescue
        nil
      end
      @dynos_by_name.data
    end

    def get_dynos_by_name
      dyno_types = get_dyno_types
      dyno_types.index_by {|dyno| dyno["name"] }
    end

    def get_dyno_types
      response = heroku.get_dyno_types(app)
      assert_heroku_api_success(response)
      response.body
    end

    def count_for_dyno_name(dyno_name)
      dyno = get_dynos_by_name_cached[dyno_name]
      return 0 unless dyno

      dyno['quantity'] || 0
    end

    def scale_dynos(dyno_name, count)
      response = heroku.post_ps_scale(app, dyno_name, count)
      assert_heroku_api_success(response)
      logger.info "Heroku.scale_dynos(#{dyno_name}, #{count})"

      response.body
    end

    def assert_heroku_api_success(response)
      raise 'Invalid Heroku API Response' unless response
      raise "Error #{response.status} from Heroku API" unless response.status == 200
    end
  end
end
