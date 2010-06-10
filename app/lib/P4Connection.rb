require 'rubygems'
require 'P4'
require 'date'

class P4Connection
  @@counter_name = 'p4rally_last_sync'
  @@time_format = '%Y/%m/%d:%H:%M:%S'
  @@server_time_format = '%Y/%m/%d %H:%M:%S %z %Z'
  attr_reader :p4

  def initialize()
    @p4 = P4.new
    @p4.port = $OPTIONS[:perforce_port]
    @p4.user = $OPTIONS[:perforce_username]
    @p4.password = $OPTIONS[:perforce_password]
    @p4.connect
    @job_fields = nil
  end
  
  def new_changelists_since(time)
    range = "//...@" + time.strftime(@@time_format) + ",now"
    puts 'executing p4 changes ' + range
    changelists = @p4.run_changes(range)
    puts 'end'
    #we have to query for the full changelist in order to get the jobs
    changelists.map{ |change| @p4.run_change("-o", change["change"]).shift }
  end

  def create_job(opts)
    # get a list of available Job fields unless we've cached them
    if @job_fields.nil?
      jobspec = @p4.run_jobspec("-o").shift
      # second word in the Fields section of the job spec 
      # contains the field name
      @job_fields = jobspec['Fields'].map{|f| f.split(' ')[1]}  
    end
    # create the job
    job = @p4.run_job("-o").shift
    opts.each do |key, value|
      # convert ruby symbol to Perforce job field name (typically CamelCase)
      spec_key = key.to_s.split('_').map{|e| e.capitalize}.join
      if @job_fields.include?( spec_key )
        job[ spec_key ] = value
      end    
    end
    @p4.save_job(job)
  end

  def last_sync_time
    last = @p4.run_counter(@@counter_name).shift["value"].to_i
    if last > 0
      return Time.at(last)
    else
      return Time.now
    end
  end

  def update_last_sync_time!
    @p4.run_counter(@@counter_name, p4_server_time.to_i.to_s)
  end

  def p4_server_time
    server_time = p4.run_info.shift["serverDate"]
    #http://stackoverflow.com/questions/800118/ruby-time-parse-gives-me-out-of-range-error
    d = Date._strptime(server_time, @@server_time_format)
    Time.local(d[:year], d[:mon], d[:mday], d[:hour], d[:min],
         d[:sec], d[:sec_fraction], d[:zone])
  end
end
