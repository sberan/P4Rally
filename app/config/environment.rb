# This script performs general bootstrapping and configuration.
require 'rubygems'

# Parse the options
require File.dirname(__FILE__) + '/option_parse'

# Add the 'lib' directory to the load path.
# Files in this directory can now be required without
# a directory.  Files in subdirectories of 'lib' can
# be required with just their subdirectory, e.g.
# require 'foo\some_file.rb' for '\app\lib\foo\some_file.rb'.
$LOAD_PATH << File.expand_path(File.dirname(__FILE__) + '/../lib')

