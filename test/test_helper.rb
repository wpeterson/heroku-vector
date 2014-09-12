require 'rubygems'
require 'bundler/setup'

require 'heroku_vector'

require 'minitest/autorun'
require 'mocha/mini_test'
require 'minitest/pride'

require 'webmock/minitest'
require 'vcr'

require 'timecop'

require 'pry'

WebMock.disable_net_connect! unless ENV['RECORD_NET']

VCR.configure do |c|
  c.cassette_library_dir = 'test/fixtures/vcr_cassettes'
  c.hook_into :webmock
end

HerokuVector.logger = Logger.new('/dev/null') if File.exist?('/dev/null')

# Webmock monkey-patch for Excon bug :(
# See: https://github.com/bblimke/webmock/issues/403
class WebMock::HttpLibAdapters::ExconAdapter

  def self.request_params_from(hash)
    hash = hash.dup
    if Excon::VERSION >= '0.27.5'
      request_keys = Excon::VALID_REQUEST_KEYS
      hash.reject! {|key,_| !request_keys.include?(key) }
    end
    PARAMS_TO_DELETE.each { |key| hash.delete(key) }
    hash
  end

end
