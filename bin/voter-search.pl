#!/usr/bin/perl
#	@(#) $Header$

use LWP::Simple qw();

my $email = shift @ARGV;

my $query = "http://groups.google.com/groups?q=author:$email";

my $response = LWP::Simple::get($query);

print "Response is: $response\n";

exit(0);
