#! /usr/bin/ruby

require '../config/environment.rb'
require 'RallyConnection'
require 'P4Connection'


rally = RallyConnection.new(:username => $OPTIONS[:rally_username],
                            :password => $OPTIONS[:rally_password],
                            :workspace => 'Sandbox',
                            :project => 'SORM')

p4 = P4Connection.new()

last_sync = p4.last_sync_time
puts "Last sync: #{last_sync}"

new_artifacts = false
new_changelists = false

rally.new_artifacts_since(last_sync).each do |artifact|
  new_artifacts = true
  puts "Creating p4 job for #{artifact.formatted_i_d}"
  p4.create_job(:job => artifact.formatted_i_d,
                :description => artifact.name,
                :group => 'scm')
end

puts 'No new rally artifacts since last sync' if !new_artifacts
p4.new_changelists_since(last_sync).each do |changelist|
  jobs = changelist['Jobs'] || []
  jobs.each do |job_name|
    artifact = rally.find_artifact(job_name)
    if artifact
      new_changelists = true
      puts "Updating artifact #{artifact.formatted_i_d} with changelist #{changelist['Change']}"
      curr_changes = ''
      if artifact.perforce_changes
        curr_changes =  artifact.perforce_changes + '<br/>'
      end
      num = changelist['Change']
      description = "<a href=\"http://perforce.ic.ncs.com/#{num}?ac=10\" target=\"_blank\">
                       #{num} - #{changelist['Description']}
                     </a>"
      artifact.update(:perforce_changes =>
                      curr_changes + description)
    end
  end
end

puts 'No new P4 changes since last sync' if !new_changelists

p4.update_last_sync_time!
