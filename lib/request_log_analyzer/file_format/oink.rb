class RequestLogAnalyzer::FileFormat::Oink < RequestLogAnalyzer::FileFormat::Rails
  line_definition :memory_usage do |line|
    line.regexp   = /Memory usage: (\d+)/
    line.capture(:memory).as(:traffic)
  end
  
  report(:append) do |analyze|
    analyze.traffic :memory_diff, :category => REQUEST_CATEGORIZER, :title => "Largest Memory Increases", :line_type => :memory_usage
  end
  
  # Keep a record of PIDs and their memory usage when validating requests.
  def pids
    @pids ||= {}
  end
  
  class Request < RequestLogAnalyzer::FileFormat::Rails::Request
   # Overrides the #validate method to handle PID updating.
   def validate
     update_pids
     super
   end
   
   # Accessor for memory information associated with the specified request PID. If no memory exists
   # for this request's :pid, the memory tracking is initialized.
   def pid_memory
     file_format.pids[self[:pid]] ||= { :last_memory_reading => -1, :current_memory_reading => -1 }
   end
    
   # Calculates :memory_diff for each request based on the last completed request that was not a failure.
   def update_pids
     # memory isn't recorded with exceptions. need to set #last_memory_reading+ to -1 as
     # the memory used could have changed. for the next request the memory change will not be recorded.
     #
     # NOTE - the failure regex was not matching with a Rails Development log file.
     if has_line_type?(:failure) and processing = has_line_type?(:processing)
       pid_memory[:last_memory_reading] = -1
     elsif mem_line = has_line_type?(:memory_usage)
        memory_reading = mem_line[:memory]
        pid_memory[:current_memory_reading] = memory_reading
        # calcuate the change in memory
        unless pid_memory[:current_memory_reading] == -1 || pid_memory[:last_memory_reading] == -1
          # logged as kB, need to convert to bytes for the :traffic Tracker
          memory_diff = (pid_memory[:current_memory_reading] - pid_memory[:last_memory_reading])*1024
          if memory_diff > 0
            self.attributes[:memory_diff] = memory_diff
          end # if memory_diff > 0
        end # unless
        
        pid_memory[:last_memory_reading] = pid_memory[:current_memory_reading]
        pid_memory[:current_memory_reading] = -1
      end # if mem_line
      return true
   end # def update_pids
  end # class Request
end
