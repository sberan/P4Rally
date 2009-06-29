#
# Copyright (C) 2009 Pearson Education, Inc. or its affiliate(s). All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'generator'

#####################
# Rally2P4 will create P4 jobs from rally artifacts.
#####################
class Rally2P4
  # The types of rally artifacts we're going to create jobs for.
  # A Hierarchical Requirement corresponds to a rally story.
  @@rally_artifact_types = [:hierarchical_requirement, :defect]
  
  # Required parameters:
  #  rally: 
  #    an instance of the rally_rest_api gem
  #  p4:
  #    an instance of the p4ruby api, with connection open
  #  oldest_artifacts_to_create:  
  #    a map containing the oldest rally artifacts to index. If these are not
  #    supplied all rally artifacts will have jobs created for them, which
  #    may take a while and be unnecessary.
  def initialize(rally, p4, oldest_artifacts_to_create={})
    @rally = rally
    @p4 = p4
    @oldest_artifacts = oldest_artifacts_to_create
  end

  # Find any new rally artifacts and create p4 jobs for them
  def create_p4_jobs
    new_rally_artifacts.each do |rally_artifact|
      create_p4_job(rally_artifact) 
    end
  end
  
  private

  # Find out if this rally artifact already has a p4 job
  # TODO: Figure out a way to look up jobs by name rather than
  #       iterating through all of them.
  def has_p4_job(rally_artifact)
    @p4.run_jobs.each do |job|
      return true if job["Job"] == rally_artifact.formatted_i_d
    end
    return false
  end

  # Create a p4 job for this rally artifact.
  # TODO: figure out the correct way to create a p4 job - this does not work
  def create_p4_job(rally_artifact)
    puts "Creating job for " + rally_artifact.formatted_i_d
    @p4.create_job(rally_artifact.formatted_i_d)
  end
  
  # Returns a list (lazily loaded) of new rally artifacts
  def new_rally_artifacts
    return Generator.new do |artifacts|
      @@rally_artifact_types.each do |type|
        @rally.find_all(type, :order => "FormattedID desc").each do |artifact|
          # If we find a job for an artifact, there should be no more
          # new rally artifacts.
          break if has_p4_job(artifact)
          
          artifacts.yield artifact
          
          # if this was the oldest artifact we're going to index, then break
          break if artifact.formatted_i_d == @oldest_artifacts[type] 
        end
      end
    end
  end
end

# This will be run as a script
if __FILE__ == $0

  # Only requiring the rally and P4 APIs here so that the unit tests
  # do not have the dependency on them.
  require 'rubygems'
  require 'rally_rest_api'
  require 'P4'

  
  rally = RallyRestAPI.new(:username => 'sam.beran@pearson.com', 
                           :password => 'password')

  p4 = P4.new
  p4.connect

  rally2p4 = Rally2P4.new(rally, p4, :hierarchical_requirement => "S11317", 
                          :defect => "DE8912")
  
  rally2p4.create_p4_jobs
end
