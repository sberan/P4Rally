require 'rally_rest_api'

class RallyConnection
  @@rally_artifact_types = [:hierarchical_requirement, :defect]
  @@rally_time_format = '%Y-%m-%dT%H:%M:%S.000Z'

  attr_reader :workspace, :project

  def initialize(opts)
    @rally_api = RallyRestAPI.new(:username => opts[:username],
                                  :password => opts[:password])
    @workspace = @rally_api.user.subscription.workspaces.find { |ws| ws.name == opts[:workspace] }
    @project = @rally_api.find(:project, :workspace => @workspace) { equal :name, opts[:project] }.first
  end

  def new_artifacts_since(time)
    time_string = time.getutc.strftime(@@rally_time_format)
    find_artifacts_where { greater_than :creation_date, time_string }
  end

  def find_artifact(id)
    begin
      artifact = find_artifacts_where { equal :formatted_i_d, id }.first
      if artifact && artifact.formatted_i_d == id
        return artifact
      else
        return nil #false match
      end
    rescue RuntimeError
      return nil
    end
  end

  def find_artifacts_where(&block)
    found_artifacts = []
    @@rally_artifact_types.each do |type|

      @rally_api.find(type, :workspace => @workspace,
                            :project => @project,
                            :fetch => true,
                            &block).each do |artifact|
        found_artifacts << artifact
      end
    end
    return found_artifacts
  end

end



