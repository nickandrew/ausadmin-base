#!/usr/bin/perl -w

#	$Revision$
#	$Date$


use strict;

my $filename=shift;

system 'pico $filename' or die "Can't edit file\n";

open POST,"<$filename" or die "Unable to open $filename $!";

open PGP,"|pgp -fast >/tmp/$$.$^T.pgp.output"
  or die "Unable to fork for pgp $!";

my @post=<POST>;

close POST or die "Unable to close $filename $!";

my $header=grep {/.*/../^$/} @post;
my $body =grep {/^$/..undef} @post;

print PGP $body;

close PGP or die "Unable to open pgp $!";

open POST,">$filename" or die "Unable to open $filename $!";

print POST $header;
print POST "\n";
print POST $body;

close POST or die "Unable to close $filename $!";

