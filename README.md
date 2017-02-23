# Jobster

This is a job queueing system based on RabbitMQ as used in in [AppMail](https://appmail.io), [MyOps](https://myops.io) and other apps I've been working on.

## Installation

```ruby
gem 'jobster'
```

## Usage

### Writing your jobs

To create a class for the job that you wish to run in the background. This class should inherit from `Jobster::Job`.

```ruby
class YourJob < Jobster::Job
  def perform
    id      #=> The job's ID
    params  #=> Any parameters that are provided when the job is queued

    # Do your bits here...
  end
end
```

### Queueing jobs

Whenever you wish to queue the job, you can do so by calling `queue` on the class and providing the name of the queue and any parameters needed to run the job.

```ruby
YourJob.queue(:main, :param1 => 'Some parameter')
```

### Running workers

You need to create a jobster worker config file. For a Rails application, it might look like this.

```ruby
# Require your Rails environment
require_relative 'environment'

# Set up which queues you wish this worker to join
Jobster::Worker.queues << :web_hooks
Jobster::Worker.queues << :mail_sending

# Set up the logger
Jobster.logger = Rails.logger
```

You'll also need to run one or more workers to actually process your jobs. Just run `jobster` followed by the path to your configuration file as the `-C` option.

```
$ jobster -c config/jobster.rb
```

You can pass a list of queues to subscribe to by providing `-q` (or `--queues`) to the `jobster` command. These should be comma separated.

### Handling errors

To handle errors which are raised in your worker, it's best to register and error handler in your worker config file. For example, if you use sentry, you might do this.


```ruby
Jobster::Worker.register_error_handler do |exception, job|
  Raven.capture_exception(exception, :extra => {:job_id => job.id})
end
```
