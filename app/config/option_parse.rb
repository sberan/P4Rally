# This script parses the options and stores them in the global variable $OPTIONS.
# It also provides appropriate feedback on the command line if the options aren't given
# correctly, or if the '-h' or '--help' options are given.
require 'optparse'

$OPTIONS = {}
$REQUIRED_OPTIONS  = []
optparse = OptionParser.new do |opts|
  # Set a banner, displayed at the top
  # of the help screen.
  # NOTE: We print [ruby] because the 'executable/entry point' script
  # has a '#! /usr/bin/ruby' at the top, meaning that on linux systems
  # it can call the ruby binary itself if it's marked as executable.
  #
  # NOTE: We print $0 because that holds the name of the 'entry point'
  # script for any ruby program, i.e. the top of the call stack.
  # We might have assumed that this script has the same name as the app.
  opts.banner = "Usage: [ruby] #{$0} [options]"

  # Define the options, and what they do.
  # NOTE: For most of these, they do nothing more than
  # set the value.  However, this approach allows us to run
  # custom code immediately upon receipt of a particular value for an option.
  #
  # These are mostly self-explanatory; comments appear only where needed.
  @opts = opts
  
  def add_option(key, short_switch, description, value_example = '', default = nil, &block)
    $OPTIONS[key] = default
    value_example.strip!
    if value_example == ''
      $OPTIONS[key] = :not_required
    else
      value_example = ' ' + value_example
    end
    
    block ||= lambda {|key, value| $OPTIONS[key] = value}
    
    @opts.on( '-' + short_switch, "--" + key.to_s + value_example, description ) do |value|
      block.call(key, value)
    end
  end
  
  
  #Define options
  add_option :rally_username, 'u', 'The Rally user name', 'USERNAME'
  add_option :rally_password, 'p', 'The Rally password', 'PASSWORD'
  add_option :rally_workspace, 'w', 'The Rally workspace', 'WORKSPACE'
  add_option :rally_project, 'r', 'The Rally Project', 'PROJECT'
  add_option :perforce_username, 'U', 'The Perforce user name', 'USERNAME'
  add_option :perforce_password, 'P', 'The Perforce password', 'PASSWORD'
  add_option :perforce_port, 't', 'The Perforce password, e.g. perforce:1666', 'PORT'
  add_option :update_last_sync_counter, 'd', 'Update last sync counter to current time and exit' do |key, value|
    $OPTIONS[key] = true
  end
  
  add_option :help, 'h', 'Display this screen' do |key, value|
    puts opts.help
    exit
  end
end

def failure_exit(optparse, error)
  puts error
  puts optparse.help
  exit
end

# Parse the command-line. Remember there are two forms
# of the parse method. The 'parse' method simply parses
# ARGV, while the 'parse!' method parses ARGV and removes
# any options found there, as well as any parameters for
# the options. What's left is the list of items in ARGV which
# aren't options, e.g. 'copy -r file1', in which case file1
# isn't an option.
begin
  optparse.parse!

  # Verify presence of each mandatory option. if value is :not_required set it to nil
  $OPTIONS.each do |k,v|
    if v.nil? || v.to_s.strip == ''
      failure_exit(optparse, k.to_s + ' is required.')
    elsif v == :not_required
      $OPTIONS[k] = nil
    end
  end
rescue OptionParser::ParseError => e
  failure_exit(optparse, e)
end

