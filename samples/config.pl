#!/usr/bin/perl
#	@(#) $Header$
#	runtime configuration file for all CGI scripts

push(@INC, "/home/ausadmin/bin");

$ENV{AUSADMIN_HOME} = "/home/ausadmin";
$ENV{AUSADMIN_DATA} = "/home/ausadmin/data";
$ENV{AUSADMIN_HIER} = "aus";

if (! -d $ENV{AUSADMIN_HOME}) {
	die "No such directory: $ENV{AUSADMIN_HOME}";
}

1;
