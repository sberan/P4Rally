#*******************************************************************************
# Copyright (c) 1997-2007, Perforce Software, Inc.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1.  Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# 2.  Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL PERFORCE SOFTWARE, INC. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#*******************************************************************************

#*******************************************************************************
#* Ruby interface to the Perforce SCM System
#*******************************************************************************


#*******************************************************************************
#* P4 class
#*******************************************************************************

#
# Get the bulk of the definition of the P4 class from the API interface
#
if RUBY_PLATFORM =~ /win32/
  require File.dirname(__FILE__) + "/win32/P4.so"
elsif RUBY_PLATFORM =~ /linux/
  require File.dirname(__FILE__) + "/linux/P4.so"
else
  raise "Platform #{RUBY_PLATFORM} doesn't have a corresponding p4.so file for P4Ruby"
end

#
# Add the extra's written purely in ruby.
#
class P4

  #
  # Named constants for the exception levels. Note they are cumulative,
  # so RAISE_ALL includes RAISE_ERRORS (as you'd expect).
  #
  RAISE_NONE    = 0
  RAISE_ERRORS    = 1
  RAISE_ALL   = 2

  #
  # Named values for merge actions. Values taken from clientmerge.h in
  # the Perforce API
  #
  MERGE_SKIP    = 1
  MERGE_ACCEPT_MERGED = 2
  MERGE_ACCEPT_EDIT = 3
  MERGE_ACCEPT_THEIRS = 4
  MERGE_ACCEPT_YOURS  = 5

  def method_missing( m, *a )

    # Generic run_* methods
    if ( m.to_s =~ /^run_(.*)/ )
      return self.run( $1, a )

      # Generic fetch_* methods
    elsif ( m.to_s =~ /^fetch_(.*)/ )
      return self.run( $1, "-o", a ).shift

      # Generic save_* methods
    elsif ( m.to_s =~ /^save_(.*)/ )
      if ( a.length == 0 )
        raise( P4Exception, "Method P4##{m.to_s} requires an argument", caller)
      end
      self.input = a.shift
      return self.run( $1, "-i", a )

      # Generic delete_* methods
    elsif ( m.to_s =~ /^delete_(.*)/ )
      if ( a.length == 0 )
        raise( P4Exception, "Method P4##{m.to_s} requires an argument", caller)
      end
      return self.run( $1, "-d", a )

      # Generic parse_* methods
    elsif ( m.to_s == "parse_forms" )
      raise( NoMethodError, "undefined method 'P4#parse_forms'", caller )
    elsif ( m.to_s =~ /^parse_(.*)/ )
      if ( a.length != 1 )
        raise( P4Exception, "Method P4##{m.to_s} requires an argument", caller)
      end
      return self.parse_spec( $1, a.shift )

      # Generic format_* methods
    elsif ( m.to_s =~ /^format_(.*)/ )
      if ( a.length != 1 )
        raise( P4Exception, "Method P4##{m.to_s} requires an argument", caller)
      end
      return self.format_spec( $1, a.shift )

      # That's all folks!
    else
      raise NameError, "No such method #{m.to_s} in class P4", caller
    end
  end

  # Aliases
  alias debug     debug=

  #
  # Simple interface for submitting. If any argument is a Hash, (or subclass
  # thereof - like P4::Spec), then it will be assumed to contain the change
  # form. All other arguments are passed on to the server unchanged.
  #
  def run_submit( *args )
    form = nil
    nargs = args.flatten.collect do
    |a|
      if ( a.kind_of?( Hash ) )
        form = a
        nil
      else
        a
      end
    end.compact

    if ( form )
      self.input = form
      nargs.push( "-i" )
    end
    return self.run( "submit", nargs )
  end

  #
  # Simple interface for using "p4 login"
  #
  def run_login( *args )
    self.input = self.password
    return self.run( "login", args )
  end

  def run_resolve( *args )
    if ( block_given? )
      self.run( "resolve", args ) do
      |default|
        yield( default )
      end
    else
      self.run( "resolve", args )
    end
  end

  #
  # Interface for changing the user's password. Supply the old password
  # and the new one.
  #
  def run_password( oldpass, newpass )
    if ( oldpass && oldpass.length > 0 )
      self.input = [ oldpass, newpass, newpass ]
    else
      self.input = [ newpass, newpass ]
    end
    self.run( "password" )
  end

  #
  # The following methods convert the standard output of some common
  # Perforce commands into more structured form to make using the
  # data easier.
  #
  # (Currently only run_filelog is defined. More to follow)


  #
  # run_filelog: convert "p4 filelog" responses into objects with useful
  #              methods
  #
  # Requires tagged output to be of any real use. If tagged output it not
  # enabled then you just get the raw data back
  #
  def run_filelog( *args )
    raw = self.run( 'filelog', args.flatten )
    raw.collect do
    |h|
      if ( ! h.kind_of?( Hash ) )
        h
      else
        df = P4::DepotFile.new( h[ "depotFile" ] )
        h[ "rev" ].each_index do
        |n|

          # If rev is nil, there's nothing here for us
          next unless h[ "rev" ][ n ]

          # Create a new revision of this file ready for populating
          r = df.new_revision

          h.each do
          |key, value|
            next unless ( value.kind_of?( Array ) )
            next unless value[ n ]
            next if ( value[ n ].kind_of?( Array ) )
            # If the field is the revision time, convert it to a Time object
            value[ n ] = Time.at( value[ n ].to_i ) if key == "time"
            r.set_attribute( key, value[ n ] )
          end

          # Now if there are any integration records for this revision,
          # add them in too
          next unless ( h[ "how" ] )
          next unless ( h[ "how" ][ n ] )

          h[ "how" ][ n ].each_index do
          |m|
            how = h[ "how" ][ n ][ m ]
            file = h[ "file" ][ n ][ m ]
            srev = h[ "srev" ][ n ][ m ]
            erev = h[ "erev" ][ n ][ m ]
            srev.gsub!( /^#/, "" )
            erev.gsub!( /^#/, "" )
            srev = ( srev == "none" ? 0 : srev.to_i )
            erev = ( erev == "none" ? 0 : erev.to_i )

            r.integration( how, file, srev, erev )
          end
        end
        df
      end
    end
  end

  #
  # Allow the user to run commands at a temporarily altered exception level.
  # Pass the new exception level desired, and a block to be executed at that
  # level.
  #
  def at_exception_level( level )
    return self unless block_given?
    old_level = self.exception_level
    self.exception_level = level
    begin
      yield( self )
    ensure
      self.exception_level = old_level
    end
    self
  end

  #*****************************************************************************
  # The P4::Spec class holds the fields in a Perforce spec
  #*****************************************************************************
  class Spec < Hash
    def initialize( fieldmap = nil )
      @fields = fieldmap
    end

    #
    # Override the default assignment method. This implementation
    # ensures that any fields defined are valid ones for this type of
    # spec.
    #
    def []=( key, value )
      if ( self.has_key?( key ) || @fields == nil )
        super( key, value )
      elsif ( @fields.has_key?( key.downcase ) )
        super( @fields[ key.downcase ], value )
      else
        raise( P4Exception, "Invalid field: #{key}" )
      end
    end

    #
    # Return the list of the fields that are permitted in this spec
    #
    def permitted_fields
      @fields.values
    end

    #
    # Implement accessor methods for the fields in the spec. The accessor
    # methods are all prefixed with '_' to avoid conflicts with the Hash
    # class' namespace. This is a little ugly, but we gain a lot by
    # subclassing Hash so it's worth it.
    #
    def method_missing( m, *a )
      k = m.to_s.downcase
      if ( k[ 0..0 ] != "_" )
        raise( RuntimeError,
                "undefined method `#{m.to_s}' for object of " +
                        "class #{self.class.to_s}" )
      end
      k = k[ 1..-1 ]

      if ( k =~ /(.*)=$/ )
        if ( a.length() == 0 )
          raise( P4Exception, "Method P4##{m} requires an argument" );
        end

        k = $1
        if ( @fields == nil || @fields.has_key?( k ) )
          return self[ @fields[ k ] ] = a.shift
        end
      elsif ( self.has_key?( m.to_s ) )
        return self[ m.to_s ]
      elsif ( @fields.has_key?( k ) )
        return self[ @fields[ k ] ]
      end
      raise( P4Exception, "Invalid field: #{$1}" )
    end
  end

  #*****************************************************************************
  #* P4::MergeInfo class
  #*****************************************************************************

  class MergeInfo

    def initialize( base, yours, theirs, merged, hint )
      @base = base
      @yours = yours
      @theirs = theirs
      @merged = merged
      @hint = hint
    end

    attr_reader   :base, :yours, :theirs, :merged, :hint
  end

  #*****************************************************************************
  # P4::Integration class
  # P4::Integration objects hold details about the integrations that have
  # been performed on a particular revision. Used primarily with the
  # P4::Revision class
  #*****************************************************************************
  class Integration
    def initialize( how, file, srev, erev )
      @how = how
      @file = file
      @srev = srev
      @erev = erev
    end

    attr_reader :how, :file, :srev, :erev
  end

  #*****************************************************************************
  # P4::Revision class
  # Each P4::Revision object holds details about a particular revision
  # of a file. It may also contain the history of any integrations
  # to/from the file
  #*****************************************************************************

  class Revision
    def initialize( depotFile )
      @depot_file = depotFile
      @integrations = Array.new
      @attributes = Hash.new
    end

    attr_reader :depot_file
    attr_accessor :integrations

    def integration( how, file, srev, erev )
      rec = P4::Integration.new( how, file, srev, erev )
      @integrations.push( rec )
      return rec
    end

    def each_integration
      @integrations.each { |i| yield( i ) }
    end

    def set_attribute( name, value )
      name = name.downcase
      if ( value =~ /^\d+$/ )
        @attributes[ name ] = value.to_i
      else
        @attributes[ name ] = value
      end
    end

    # Define #type and #type= explicitly as they clash with the
    # deprecated Object#type. As it is deprecated, this clash should
    # disappear in time.
    def type
      @attributes[ 'type' ]
    end

    def type=( t )
      @attributes[ 'type' ] = t
    end

    #
    # Generic getters and setters for revision attributes.
    #
    def method_missing( m, *a )
      k = m.to_s.downcase
      if ( k =~ /(.*)=$/ )
        if ( a.length() == 0 )
          raise( P4Exception, "Method P4##{m} requires an argument" );
        end
        k = $1
        @attributes[ k ] = a.shift
      else
        @attributes[ k ]
      end
    end
  end

  #*****************************************************************************
  # P4::DepotFile class.
  # Each DepotFile entry contains details about one depot file.
  #*****************************************************************************
  class DepotFile
    def initialize( name )
      @depot_file = name
      @revisions = Array.new
      @headAction = @head_type = @head_time = @head_rev = @head_change = nil
    end

    attr_reader :depot_file, :revisions
    attr_accessor :head_action, :head_type, :head_time, :head_rev, :head_change

    def new_revision
      r = P4::Revision.new( @depot_file )
      @revisions.push( r )
      return r
    end

    def each_revision
      @revisions.each { |r| yield( r ) }
    end
  end

end # class P4
