# Heroku Vector

Simple, linear auto scaling for Heroku dynos.

Heroku Vector runs as a multi-threaded process that samples production metrics and linearly scales Heroku dynos up or down as they change.

Web Dynos can be scaled using the amount of traffic (RPM) from NewRelic.  Sidekiq dynos can be scaled based on how many worker threads are busy.

## Installation

Install this gem:

    $ gem install heroku_vector

And then run the scaler proces:

    $ heroku_vector --help

## Configuration

This auto scaler will sample metrics and use the metric values to scale different types of Heroku Dynos up or down.

```ruby 

# Example config.rb file
HerokuVector.configure do |config|

  # Scale 1 web dyno for each 300rpm of traffic
  config.add_dyno_scaler('web', {
    source:         HerokuVector::Source::NewRelic,
    period:         60,
    min_dynos:      1,
    max_dynos:      10,
    min_value:      100,
    max_value:      300
  })

  # Manually specify app config in config.rb like so
  # Alternately, use environment variables
  config.newrelic_api_key = '222222222222222'

end
```

Application config can be wired up in the config.rb file, or passed in via the system Environment or an Environment file:

```bash
HEROKU_APP_NAME=your-app-name
HEROKU_API_KEY=1111111111111111
REDIS_URL=redis://redis.yourcompany.com/
SIDEKIQ_REDIS_NAMESPACE=sidekiq
NEWRELIC_API_KEY=222222222222222
```

## Architecture

The auto-scaler runs as a single process, either interactively or as a daemon (`ProcessManager`).  Within that process, the `Worker` spawn an EventMachine event loop and runs each `DynoScaler` in it's own thread.  Periodically, each `DynoScaler` will sample data and evaluate the scale of your dynos.  When the scale of your dynos doesn't match your traffic, the `DynoScaler` will use the Heroku API to scale your dynos up or down.

## Adding a new Source

Data is sampled from generic `Source` classes in the Ruby namespace `HerokuVector::Source` and wired up in your configuration.  Source objects have a simple contract:

* `#sample` - returns a numeric value for this source at this time
* `#units` - string that describes the data, like 'RPM' for NewRelic

You can define your own `Source` classes and then reference them within your config:

```ruby
# my_data_source.rb
module HerokuVector::Source
  class MyDataSource
    def sample
      # Always returns 1, simple test case
      1
    end

    def units
      'foos'
    end
  end
end

# Wire Up Your Source in config.rb
require 'path/to/my_data_source'

HerokuVector.configure do |config|

  # Scale 1 web dyno for each 300rpm of traffic
  config.add_dyno_scaler('web', {
    source:         HerokuVector::Source::MyDataSource,
    period:         1
  })

```

## Contributors: :heart:

* Your Name Could Go Here

## Contributing

1. Fork it
2. Bundle Install (`bundle install`)
3. Run the Tests (`rake test`)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
