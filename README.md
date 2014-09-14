# Heroku Vector
![Build Status](https://travis-ci.org/wpeterson/heroku-vector.svg?branch=master)

```bash
  ___ ___                           __                  
 /   |   \   ____  _______   ____  |  | __ __ __        
/    ~    \_/ __ \ \_  __ \ /  _ \ |  |/ /|  |  \       
\    Y    /\  ___/  |  | \/(  <_> )|    < |  |  /       
 \___|_  /  \___  > |__|    \____/ |__|_ \|____/        
      ____   ____/                 __   \/              
      \   \ /   /  ____    ____  _/  |_   ____  _______ 
       \   Y   / _/ __ \ _/ ___\ \   __\ /  _ \ \_  __ \
        \     /  \  ___/ \  \___  |  |  (  <_> ) |  | \/
         \___/    \___  > \___  > |__|   \____/  |__|   
                      \/      \/                        
```

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

## Defining Your Dyno Scalers
The core configuration within Heroku Vector is defining a set of `Dyno Scalers` that monitor a type of Heroku dyno (like `web` or `worker` dynos).  The DynoScaler monitors the number of this type of dynos and the amount of traffic they are getting, by sampling data from the traffic source.  Heroku Vector provides a simple DSL for adding a Dyno Scaler:

```ruby
HerokuVector.configure do |config|
  # App Settings go here

  # Define a dyno scaler with:
  config.add_dyno_scaler(DYNO_NAME, options={})

  #...
end
```

Each dyno scaler requires the name of the type of dyno (eg: `web`), and some options.

### Options

*  `min_value` - REQUIRED - Minimum amount of traffic per-dyno (scale down when traffic below)
*  `max_vaue` - REQUIRED - Maximum amount of trafic per-dyno (scale up when traffic is above)
*  `source` - REQUIRED - Traffic Data Source to sample, either a Ruby class or string class name. (eg: `HerokuVector::Source::NewRelic`)
*  `period` - OPTIONAL - How often to sample the traffic source, in seconds, defaults to every 1 minute (60 sec)
*  `min_dynos` - OPTIONAL - Minimum number of dynos to have running at all times, defaults to 2.
*  `max_dynos` - OPTIONAL - Maximum number of dynos to run at any time, defaults to 10.
*  `scale_up_by` - OPTIONAL - Number of dynos to scale up by, defaults to 1 at a time.
*  `scale_down_by` - OPTIONAL - Number of dynos to scale down by, defaults to 1 at a time.

## Application Settings
Settings can be configured via the `HerokuVector.config do {|config| }` API or as Environment variables or an environment file for sensitive values like API keys.  Here are the top-level application settings that can be changed:

*  `config.logger` - Ruby Logger instance, defaults to a built-in logger wrapping `STDOUT`
*  `config.engine` - Scaling Engine to use, defaults to Heroku API scaler
*  `config.min_scale_time_secs` - Minimum scaling rate-limit (only scale up/down this often), defaults to 5 mins (300sec).  Rate limit is per-Dyno Scaler, so web and worker dynos have their own rate limits.

## Sources and Config
Heroku Vector is designed to have a modular system for pulling traffic data from a variety of sources.  The current sources are listed below, with any settings they need:

### NewRelic

    Minimum Period: 60sec
    Unit: Requests per Minute (RPM)
    Default Sample Size: Last 5 Minutes (300 samples)

This data source pulls the Throughput in Request per Minute (RPM) from the NewRelic API for the last minute of data.  NewRelic metrics tend to lag 3-5 minutes behind realtime.

* `config.newrelic_api_key` / `ENV['NEWRELIC_API_KEY']` - REQUIRED - Secret API Key for your newrelic account.
* `config.newrelic_account_id` / `ENV['NEWRELIC_ACCOUNT_ID']` - OPTIONAL - ID of NewRelic Account to pull from, defaults to first account.
* `config.newrelic_app_id` / `ENV['NEWRELIC_APP_ID']` - OPTIONAL - ID of NewRelic Application to pull from, defaults to first Application in the account.

### Sidekiq

    Minimum Period: 1sec
    Unit: # busy threads
    Default Sample Size: Last 2 Minutes (120 samples)

This data source samples the realtime number of busy worker threads in a sidekiq cluster, using the Sidekiq data API.  This value can be sampled continuously.

* `config.sidekiq_redis_url` / `ENV['REDIS_URL']` - OPTIONAL - URL for Redis backing Sidekiq cluster, defaults to `localhost` on `6379`
* `config.sidekiq_redis_namespace` / `ENV['SIDEKIQ_REDIS_NAMESPACE']` - OPTIONAL - Redis namespace for Sidekiq cluster, default is no namespace used.

## heroku_vector daemon:
```bash
[master ~/src/heroku-vector]$> ./bin/heroku_vector --help
heroku_vector: auto-scale dynos on Heroku

  Usage: heroku_vector [options]
         heroku_vector -s

    -s, --sample                     Sample values and exit
    -d, --daemonize                  Daemonize process
    -e, --envfile PATH               Environment file (default: .env)
    -c, --config PATH                Config file (default: config.rb)
    -p, --pidfile PATH               Daemon pid file (default: heroku_vector.pid)
    -x, --loglevel LEVEL             Logging level [fatal/warn/info/debug] (default is info)
    -l, --logfile PATH               Logfile path for daemon
    -h, --help                       Show this message
```

Once you've configured your API keys and host names, try taking a sample from all your sources:

```bash
$> heroku_vector -s
heroku_vector: {:daemonize=>false, :envfile=>"/Users/wpeterson/src/heroku-vector/.env", :config=>"/Users/wpeterson/src/heroku-vector/config.rb", :sample=>true}
HerokuVector::Source::NewRelic: 8490.0 RPM
HerokuVector::Source::Sidekiq: 23 busy threads
```

## Logging and Debugging

Heroku Vector logs either to `STDOUT` or a logfile with useful information about state changes and scaling events.

```bash
2014-09-12T16:05:48.473Z INFO: Loading config from '/home/ubuntu/polar-auto-scale/config.rb'
2014-09-12T16:05:48.474Z INFO: Loading Scaler: web, {:source=>HerokuVector::Source::NewRelic, :period=>60, :min_dynos=>1, :max_dynos=>4, :min_value=>1000, :max_value=>3000}
2014-09-12T16:05:48.474Z INFO: Loading Scaler: worker, {:source=>HerokuVector::Source::Sidekiq, :period=>5, :min_dynos=>1, :max_dynos=>10, :min_value=>0.5, :max_value=>3, :scale_up_by=>3, :scale_down_by=>1}
2014-09-12T16:45:01.742Z INFO: Heroku.scale_dynos(worker, 4)
2014-09-12T16:50:03.164Z INFO: worker: 4 dynos - 0.4 busy threads below 2.0 - scaling down
2014-09-12T16:50:03.247Z INFO: Heroku.scale_dynos(worker, 3)
2014-09-12T16:55:04.559Z INFO: worker: 3 dynos - 0.2 busy threads below 1.5 - scaling down
2014-09-12T16:55:04.646Z INFO: Heroku.scale_dynos(worker, 2)
2014-09-12T17:00:08.391Z INFO: worker: 2 dynos - 0.9 busy threads below 1.0 - scaling down
2014-09-12T17:00:08.492Z INFO: Heroku.scale_dynos(worker, 1)
```

If you're debugging a problem, you can turn on verbose logging by setting the `debug` log level:

    $ heroku_vector -x debug

## Architecture

![Architecture](https://dl.dropboxusercontent.com/s/a133uy8e0ohwp9t/Architecture.png?dl=0)

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
![Build Status](https://travis-ci.org/wpeterson/heroku-vector.svg?branch=master)

1. Fork it
2. Bundle Install (`bundle install`)
3. Run the Tests (`rake test`)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
