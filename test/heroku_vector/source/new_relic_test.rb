require File.absolute_path File.dirname(__FILE__) + '/../../test_helper'

describe HerokuVector::Source::NewRelic do
  let(:api_key) { 'api_key' }
  let(:account_id) { 1 }
  let(:app_id) { 2 }
  
  let(:source) do
    HerokuVector::Source::NewRelic.new(
      api_key: api_key
    )
  end

  describe '#initialize' do
    it 'should load newrelic defaults from HerokuVector' do
      HerokuVector.expects(:newrelic_api_key => api_key)
      HerokuVector.expects(:newrelic_app_id => app_id)
      HerokuVector.expects(:newrelic_account_id => account_id)

      source = HerokuVector::Source::NewRelic.new

      assert_equal api_key, source.api_key
      assert_equal app_id, source.app_id
      assert_equal account_id, source.account_id
    end

    it 'should take options on init' do
      HerokuVector.expects(:newrelic_api_key).never
      HerokuVector.expects(:newrelic_app_id).never
      HerokuVector.expects(:newrelic_account_id).never

      source = HerokuVector::Source::NewRelic.new(api_key: api_key, app_id: app_id, account_id: account_id)

      assert_equal api_key, source.api_key
      assert_equal app_id, source.app_id
      assert_equal account_id, source.account_id
    end
  end

  describe '#newrelic_account' do
    it 'should lookup account from New Relic API' do
      VCR.use_cassette('newrelic_account') do
        account = source.newrelic_account
        assert_equal api_key, account.api_key
      end
    end
  end

  describe '#newrelic_app' do
    it 'should load app from NewRelic API' do
      VCR.use_cassette('newrelic_app') do
        app = source.newrelic_app

        assert_equal 'polar-rails-staging', app.name
      end
    end
  end

  describe '#throughput' do
    it 'should load threshold values and throughput from NewRelic API' do
      VCR.use_cassette('newrelic_threshold_values') do
        value = source.throughput
        assert_equal 123, value
      end
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
