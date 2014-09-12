require 'newrelic_api'

module HerokuVector::Source
  class NewRelic
    attr_reader :account_id, :app_id, :api_key

    def initialize(options={})
      options[:api_key] ||= HerokuVector.newrelic_api_key
      options[:account_id] ||= HerokuVector.newrelic_account_id
      options[:app_id] ||= HerokuVector.newrelic_app_id

      @api_key = options[:api_key]
      @account_id = options[:account_id]
      @app_id = options[:app_id]

      NewRelicApi.api_key = api_key
    end

    def newrelic_account
      # Safe to memoize the parent Account
      @newrelic_account ||= NewRelicApi::Account.find(account_id || :first)
    end

    def newrelic_app
      # App Must be fetched from network every time, to get latest metrics
      if app_id
        newrelic_account.applications.find {|app| app.id == app_id }
      else
        newrelic_account.applications.first
      end
    end

    def throughput
      begin
        # Fetch fresh App instance and extract Trhoughput metric from Threshold Values
        # Threshold Values are current instantaneous measures, not periodic averages
        metric = newrelic_app.threshold_values.find {|m| m.name == 'Throughput' }
        metric.metric_value
      rescue
        return 0.0
      end
    end
    alias_method :sample, :throughput

    def unit
      'RPM'
    end

  end
end
