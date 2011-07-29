# Remote Run.

Our development team wanted a way to distribute our test suite to many machines
to reduce the total run time.  Remote Run is intended to be a simple way to 
run a list of shell scripts on a pool of hosts until all have completed. 

When two Remote Runs are in progress, the runners will compete to lock
machines until all tasks are complete.


## Example: 

        require 'rubygems'
        require 'remote_run'

        hosts = ["broadway", "wall"]
        setup = "source ~/.profile; rvm use ree; bundle install;"
        tasks = [
          "#{setup} bundle exec rspec spec/models",
          "#{setup} bundle exec rspec spec/controllers"
        ]

        # configure runner
        runner = Runner.new do |config|
          config.hosts = hosts
          config.tasks = tasks
        end

        # kick off the run
        runner.run


## Configuration Options:

        Required:
        hosts - hostnames of remote machines.
        tasks - a string that is a shell script to be run on one of the hosts.

        Optional:
        local_path - the local path to be rsync'd  (default: working directory)
        temp_path - the location where the working directory is cached on the local machine when starting a run (default: /tmp/remote)
        remote_path - the location to rsync files to on the remote host.  (default: /tmp/remote)
        exclude - directories to exclude when rsyncing to remote host (default: [])
        login_as - the user used to log into ssh (default: current user)


## Accessible Attributes:

        local_hostname - your computer's hostname
        identifier - a unique identifier for your test run


## What it Does:

* checks that all hosts can be logged into via ssh
* runs each task on a remote host in parallel
  * finds an unlocked remote host
  * locks a remote host (puts a file on the remote host)
  * finds a task to run
  * forks a separate process and gives it the selected task
    - rsyncs your current directory to the locked remote host
    - via ssh, runs a shell command of your choice on the locked remote host
    - unlocks the machine (removes the file from the remote host)
    - returns the status code of the shell script
  * finds the next machine to be locked
  * waits for all forks to return
  * displays success message if all status codes from the forks are zero (0)
  * displays failure message if any status codes from the forks are non-zero


Dependencies:
----------------------------------------------------------------------
* HighLine 


License:
----------------------------------------------------------------------

MIT
