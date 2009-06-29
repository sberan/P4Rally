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

require 'rally2p4'
require 'test/unit'
require 'test/unit/ui/console/testrunner'

# Mock of p4ruby gem
class MockP4
  attr_reader :jobs
  def initialize
    @jobs = []
  end

  def run_jobs
    @jobs
  end
  
  #TODO: find the correct way to create a p4 job
  def create_job(name)
    @jobs << {"Job" => name}
  end
end


class MockRallyArtifact
  def initialize(id)
    @id = id
  end

  def formatted_i_d
    @id
  end
end

# Mock of the rally_rest_api gem
class MockRally
  attr_reader :artifacts
  def initialize
    @artifacts = {:defect => [], :hierarchical_requirement => []}
  end

  def find_all(type, options)
    @artifacts[type].sort_by{ |artifact| artifact.formatted_i_d }.reverse
  end
end

class TestRally2P4 < Test::Unit::TestCase
  def setup
    @mock_rally = MockRally.new
    @mock_p4 = MockP4.new
    @rally2p4 = Rally2P4.new(@mock_rally, @mock_p4, :defect => "DE001", 
                                                    :hierarchical_requirement => "S001")
  end

  def test_rally_artifacts_should_create_p4_jobs
    @mock_rally.artifacts[:hierarchical_requirement] <<  MockRallyArtifact.new("S001")
    @rally2p4.create_p4_jobs
    assert(@mock_p4.jobs[0]["Job"] == "S001", 
           "A p4 job should have been created from a rally story")
    
    @mock_rally.artifacts[:defect] << MockRallyArtifact.new("DE001")
    @rally2p4.create_p4_jobs
    assert(@mock_p4.jobs[1]["Job"] == "DE001", 
           "A p4 job should have been created from a rally defect")

    @mock_rally.artifacts[:defect] << MockRallyArtifact.new("DE000")
    @mock_rally.artifacts[:hierarchical_requirement] << MockRallyArtifact.new("S000")
    @rally2p4.create_p4_jobs
    assert(@mock_p4.jobs.size == 2, 
          "Artifacts should not be added twice, and old artifacts should not be created")
  end
end


if __FILE__ == $0
  Test::Unit::UI::Console::TestRunner.run(TestRally2P4)
end


