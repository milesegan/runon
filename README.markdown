DESCRIPTION
===========
runon is a simple tool that executes commands in batches across a group of computers.

INSTALLATION
------------
runon requires ocaml to build. However, compilation can produce a standalone executable
with no dependencies.

To compile, first install ocaml from http://caml.inria.fr

Then issue one of the following commands:

to build the bytecode version:

    make

to build a standalone, native version:

    make opt

Then simply runon or runon.opt into your path.

USAGE
-----
Run runon with no arguments to get a usage summary.

The basic usage is:

    runon [command] [hosts]

where command is a command to be run and hosts is a list of the names of the
hosts upon which you wish to run the command. The default transport is ssh. You
should set up ssh key access on all the target machines before invoking runon.

For example:
    
    runon "cat /etc/motd" parrot jay pelican
