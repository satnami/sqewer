require_relative '../spec_helper'

describe Sqewer::CLI, :sqs => true do
  describe 'runs the commandline app, executes jobs and then quits cleanly' do
    it 'on a USR1 signal' do
      submitter = Sqewer::Connection.default
    
      stderr = Tempfile.new('worker-stderr')
    
      pid = fork { $stderr.reopen(stderr); exec("ruby #{__dir__}/cli_app.rb") }
  
      Thread.new do
        20.times do
          j = {job_class: 'MyJob', first_name: 'John', last_name: 'Doe'}
          submitter.send_message(JSON.dump(j))
        end
      end
   
      sleep 2
      Process.kill("USR1", pid)
      sleep 0.5
      $stderr.puts stderr.read()
      
      generated_files = Dir.glob('*-result')
      expect(generated_files).not_to be_empty
      generated_files.each{|path| File.unlink(path) }
    
      stderr.rewind
      log_output = stderr.read
      expect(log_output).to include('Stopping (clean shutdown)')
    end
    
    it 'on a TERM signal' do
      submitter = Sqewer::Connection.default
    
      stderr = Tempfile.new('worker-stderr')
    
      pid = fork { $stderr.reopen(stderr); exec("ruby #{__dir__}/cli_app.rb") }
  
      Thread.new do
        20.times do
          j = {job_class: 'MyJob', first_name: 'John', last_name: 'Doe'}
          submitter.send_message(JSON.dump(j))
        end
      end
   
      sleep 2
      Process.kill("TERM", pid)
      sleep 0.5
    
      generated_files = Dir.glob('*-result')
      expect(generated_files).not_to be_empty
      generated_files.each{|path| File.unlink(path) }
    
      stderr.rewind
      log_output = stderr.read
      expect(log_output).to include('Stopping (clean shutdown)')
    end
  end
end