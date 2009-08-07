# This script parses the options and stores them in the global variable $OPTIONS.
# It also provides appropriate feedback on the command line if the options aren't given
# correctly, or if the '-h' or '--help' options are given.
require 'optparse'

$OPTIONS = {}

optparse = OptionParser.new do|opts|
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
  $OPTIONS[:rally_username] = nil
  opts.on( '-u', '--rally-username USERNAME', 'The Rally user name' ) do |rally_username|
    $OPTIONS[:rally_username] = rally_username
  end

  $OPTIONS[:rally_password] = nil
  opts.on( '-p', '--rally-password PASSWORD', 'The Rally password' ) do |rally_password|
    $OPTIONS[:rally_password] = rally_password
  end

  $OPTIONS[:rally_workspace] = nil
  opts.on( '-w', '--rally-workspace WORKSPACE', 'The Rally workspace' ) do |rally_workspace|
    $OPTIONS[:rally_workspace] = rally_workspace
  end

  $OPTIONS[:perforce_username] = nil
  opts.on( '-U', '--perforce-username USERNAME', 'The Perforce user name' ) do |perforce_username|
    $OPTIONS[:perforce_username] = perforce_username
  end

  $OPTIONS[:perforce_password] = nil
  opts.on( '-P', '--perforce-password PASSWORD', 'The Perforce password' ) do |perforce_password|
    $OPTIONS[:perforce_password] = perforce_password
  end

  $OPTIONS[:perforce_port] = nil
  opts.on( '-t', '--perforce-port PORT', 'The Perforce password, e.g. perforce:1666' ) do |perforce_port|
    $OPTIONS[:perforce_port] = perforce_port
  end

  # This displays the help screen
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
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

  # Verify presence of each mandatory option.
  # All options are currently mandatory.
  # (You'd think OptionParser could do this for us, since it
  # allows us to specify mandatory/optional options.)
  $OPTIONS.each do |k,v|
    unless v && v.strip != ''
      puts optparse.help
    exit
    end
  end
rescue OptionParser::ParseError => e
  puts optparse.help
end

