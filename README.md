Conveyor Belt is an SQS based queue processor.

## Job storage

Jobs are (by default) stored in SQS as JSON blobs. A very simple job ticket looks like this:

    {
      "job_class": "MyJob"
    }

When this ticket is being picked up by the worker, the worker will do the following:

    job = MyJob.new
    job.run

So the smallest job class has to be instantiatable, and has to respond to the `run` message.

## Jobs with arguments and parameters

Job parameters can be passed as keyword arguments. Properties in the job ticket (encoded as JSON) are
directly translated to keyword arguments of the job constructor. With a job ticket like this:

    {
      "job_class": "MyJob",
      "ids": [1,2,3]
    }

the worker will instantiate your `MyJob` class with the `ids:` keyword argument:

    job = MyJob.new(ids: [1,2,3])
    job.run

## Jobs spawning dependent jobs

If your `run` method on the job object accepts arguments (has non-zero `arity` ) the `ExecutionContext` will
be passed to the `run` method.

    job = MyJob.new(ids: [1,2,3])
    job.run(execution_context)

The execution context has some useful methods:

 * `logger`, for logging the state of the current job. The logger messages will be prefixed with the job's `inspect`.
 * `submit!` for submitting more jobs to the same queue

A job submitting a subsequent job could look like this:

    class MyJob
      def run(ctx)
        ...
        ctx.submit!(DeferredCleanupJob.new)
      end
    end

## Job submission

In general, a job object that can be submitted must return a Hash from it's `to_h` method. The hash must
include all the keyword arguments needed to instantiate the job when executing. For example:

    class SendMail
      def initialize(to:, body:)
        ...
      end
      
      def run()
        ...
      end
      
      def to_h
        {to: @to, body: @body}
      end
    end

Or if you are using `ks` gem (https://rubygems.org/gems/ks) you could inherit your Job from it:

    class SendMail < Ks.strict(:to, :body)
      def run
        ...
      end
    end

## Starting and running the worker

The very minimal executable for running jobs would be this:

    #!/usr/bin/env ruby
    require 'my_applicaion'
    ConveyorBelt::CLI.run

This will connect to the queue at the URL set in the `SQS_QUEUE_URL` environment variable.

You can also run a worker without signal handling, for example in test
environments. Note that the worker is asynchronous, it has worker threads
which do all the operations by themselves.

    worker = ConveyorBelt::Worker.new
    worker.start
    # ...and once you are done testing
    worker.stop

## Configuring the worker

One of the reasons this library exists is that sometimes you need to set up some more
things than usually assumed to be possible. For example, you might want to have a special
logging library:

    worker = ConveyorBelt::Worker.new(logger: MyCustomLogger.new)

Or you might want a different job serializer/deserializer (for instance, if you want to handle
S3 bucket notifications coming into the same queue):

    worker = ConveyorBelt::Worker.new(serializer: CustomSerializer.new)

The `ConveyorBelt::CLI` module that you run from the commandline handler application accepts the
same options as the `Worker` constructor, so everything stays configurable.