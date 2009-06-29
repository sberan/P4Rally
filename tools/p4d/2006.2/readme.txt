===================================
Running the Perforce Server Locally
===================================

This directory contains p4d.exe, the Perforce server binary, as well as p4s.exe, the Windows service version of the binary.  There is no install process, you simply run the binary (as described below).

This practice was borrowed from the Instance Configuration project, which may also have useful scripts and tools for developing with Perforce.

====
Why?
====

When running our app in non-production environments, we shouldn't be hitting the production Perforce server.  This is an attempt to follow a good practice from Ruby on Rails, in which the convention, for database-backed apps, is to run a single MySQL instance on the developer machine, with one database for each local environment such as 'development' and 'test'  Common environments such as 'acceptance_test' (if defined), can also use their own p4d instance.

On a typical developer machine, we'll run a single instance of the Perforce server software, with multiple depots, or one depot with a folder, for each environment, e.g.

//depot/p4rally-challenge/development
//depot/p4rally-challenge/test

The Perforce server software is free as long as we don't create more than two user accounts or five client specs per instance.

====
How?
====

Follow the remaining steps to set up the Perforce server software and the necessary configuration.  NOTE: You may run the Perforce server as a Windows service or simply from the command line.


To run from the command line
-----------------------------

Simply execute p4d.exe, which takes a number of arguments ('p4d -h' will list them).  The only ones I use are:

p4d -p 1666 -r c:\temp\p4root

'-p' gives the P4PORT value, '-r' gives the P4ROOT directory, where the depot files and metadata are kept.


To run as a Windows service
----------------------------

This requires a couple of steps, but is more convenient in some ways.

1. Install the service using the following command:

svcinst create -n Perforce -e (location of p4s.exe)

2. Set the P4ROOT and P4PORT variables for the service:

p4 set -S Perforce P4ROOT=c:\temp\p4root
p4 set -S Perforce P4PORT=1666

3. Start the service

Execute 'net start Perforce'


Test the server
---------------

Execute 'p4 -p 1666 info'.  This should return the connection info for your local server, regardless of whether you run as a service or from the command line.


Staying within the two-user limit for free installations
--------------------------------------------------------

Unfortunately, by default, Perforce will add a user anytime you reference them, if there are licenses available.  For example, suppose a 'find user' unit test looks for a user we know doesn't exist, e.g. 'notgonnabethere'.  Perforce will add them!  So, you can quickly  run up against the license limit.  To avoid this, we must change the Perforce 'protect' table so that only the admin user can create users.  If you wish to do it manually, you must run 'p4 protect' and remove the following line:

'write user * * //...'

and add

'super user admin * //...'  (Assuming 'admin' is your super-user name)


Brian Hartin
June 29, 2009