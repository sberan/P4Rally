#
# Requires the P4Ruby API, available from Perforce
# NOTE: Ordinarily, we do not need to use '.rb'
# in a require statement.  However, in this case,
# Perforce has provided 'P4.so' (a compiled C library)
# so we must distinguish between the two (since 'so' files can also
# be 'required')
require File.dirname(__FILE__) + '/lib/P4.rb'

# = Introduction
# This module exists to provide an abstraction of the P4Ruby
# library so that model classes can be free from Perforce details.
# The aim is that business logic methods interact with Perforce very
# simply, e.g. connect(), list_jobs(), find_job(), etc.  This class does
# not have any knowledge of the models.
#
# == Perforce Knowledge Required
# This module, and this its documentation, assumes the user is familiar
# with Perforce.  Executing 'p4 help' and 'p4 help commands' from the
# command line will get you very far.
#
# == Connecting to Perforce
# Since our app uses Perforce as a data store, we have tried to use
# conventions similar to those rails has for databases, e.g. config\perforce.yml
# (instead of config\database.yml) defines connection properties for each environment.
# Likewise, we have a 'p4:fixtures:load' rake task instead of 'db:fixtures:load', as well
# as mechanisms in p4_test_helper for populating fixture data from \test\fixtures.
#
# Methods take the user ID and password (if necessary), taking advantage of P4Ruby's
# ability to use a given user ID and password for a given instruction without
# obtaining a Perforce ticket, i.e. a persistent authentication for a given user.
# This mimics the p4 command line's '-u' and '-P' arguments.
#
# == File references
# Methods that take a 'depot_file' argument require a fully-qualified path
# to a file in Perforce, e.g. //pem_rd/x/y/z.xml.  Methods that take a 'client_file'
# argument expect a fully-qualified path to a file in the appropriate client workspace.
# Some methods may take either, and so indicate by taking a 'depot_or_client_file'
# argument.
module P4Helper
  # A module-level variable holding the P4Ruby object.
  @@p4 = P4.new

  # Reads and caches the information in config/perforce.yml, and
  # returns it as a hash.
  def p4_config
    unless defined? @@configuration && @@configuration
      yaml = File.open(File.join(File.dirname(__FILE__), 'config','perforce.yml')) {|yf| YAML::load( yf )}
      puts "yaml is #{yaml.inspect}"
      @@configuration = yaml[ENV['APP_ENV']] # Allows string or symbol keys
    end
    @@configuration
  end


  # Return true if a connection to Perforce has been established
  # connected. NOTE: This doesn't mean we're authenticated or that
  # we've obtained a Perforce 'ticket'; this is a P4Ruby-specific
  # notion of connection.
  def connected?
    @@p4 && @@p4.connected?
  end

  # Connect or raise P4ConnectionException, using the p4_config[:port] constant.
  def connect()
    unless connected?
      @@p4.port = p4_config['port'].to_s # Comes from environment.rb or development.rb, etc.
      @@p4.connect
    end
  rescue P4Exception
    raise P4ConnectionException, "Could not connect to Perforce using the given configuration."
  end

  # Disconnect.
  def disconnect
    @@p4.disconnect
  end

  # Authenticate the user, raising P4AuthenticationException if this fails.
  def authenticate(user_id, password)
    run_authenticated(user_id, password) do
      @@p4.run_login # Guaranteed to fail with bad user_id/password
      @@p4.run_logout # This _doesn't_ need to be in an ensure block
    end
  end

  # Finds the P4::Spec containing the user's details.
  def find_user_spec(user_id, password, user_id_to_find = user_id)
    run_authenticated(user_id, password) do
      p4_user_spec = @@p4.fetch_user(user_id_to_find) # If the user_id isn't found, we will still get a spec back.
      p4_user_spec if p4_user_spec["Update"] || p4_user_spec["Access"]  # but the spec won't have these fields.
    end
  end


  # Lists the files matching a given view (see 'p4 help view')
  # as an Array of their qualified Perforce filenames,
  # e.g. ['//a/b/c.txt', '//a/b/d.txt'].
  def list_files(user_id, password, view, revision = 'head')
    revision ||= 'head' # Handles explicit nils
    run_authenticated(user_id, password) do
      val = @@p4.run_files("#{view}##{revision}")
      val.reject! {|f| f['action'] == 'delete'} # Ignore deleted revisions
      val.collect! {|f| f['depotFile']} # Return just the names
    end
  rescue P4Exception => p4Ex
    if p4Ex.message =~ /no such.*file/
      []
    else
      raise
    end
  end

  # Retrieves a P4DepotFile object, given a depot or local file and a revision specifier.
  # Returns nil if the file isn't found or was deleted (at the given revision).
  def find_file(user_id, password, depot_or_client_file, revision = 'head')
    revision ||= 'head' # Handles explicit nils
    run_authenticated(user_id, password) do
      p4_fstat_results = @@p4.run_fstat("#{depot_or_client_file}##{revision}")
      if p4_fstat_results[0]["headAction"] != "delete" # It might have been deleted
        @@p4.run_filelog("-l", "#{depot_or_client_file}##{revision}")[0]
      end
    end
  rescue P4Exception => p4Ex
    raise p4Ex unless p4Ex.message =~ /no such file/
  end


  # Return a changelist spec if given a valid changelist number, nil otherwise.
  def changelist(user_id, password, changelist_number)
    run_authenticated(user_id, password) do
      @@p4.fetch_changelist(changelist_number)
    end
  end


  # Represents a connection error.
  class P4ConnectionException < Exception

  end

  # Represents an authentication error.
  class P4AuthenticationException < Exception

  end

  protected

  # Connect, if necessary, and run a block of code.
  def run_connected(&block)
    was_connected = connected?
    connect unless was_connected
    yield
  ensure
    disconnect unless was_connected
  end

  # Runs the given block for the given
  # user, setting user info back to previous user info afterward.
  # This is equivalent to running a p4 command with the
  # -u and -P options, e.g. 'p4 -u username -P password sync //...'
  def run_authenticated(user_id, password, &block)
    old_user_id, old_password = @@p4.user, @@p4.password
    run_connected do
      begin
        raise P4AuthenticationException, "You must provide a user id" if !user_id || user_id.strip == ""
        @@p4.user, @@p4.password = user_id.to_s, password.to_s
        yield
      rescue P4Exception => p4Ex
        if p4Ex.message =~ /\(P4PASSWD\) invalid or unset|Password invalid|Access for user '#{user_id}' has not been enabled|User #{user_id} doesn't exist/
          raise P4AuthenticationException, "User #{user_id} could not log in to Perforce using the given password."
        else
          raise
        end
      ensure
        @@p4.user, @@p4.password = old_user_id, old_password
      end
    end
  end
end
