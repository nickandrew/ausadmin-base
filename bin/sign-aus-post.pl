#!/usr/bin/perl -w
#
# $Source$
# $Revision$
# $Date$


use strict;

my $filename=shift;

system "pico $filename";

open POST,"<$filename" or die "Unable to open $filename $!";

open PGP,"|pgp -fast >/tmp/$$.$^T.pgp.output"
  or die "Unable to fork for pgp $!";

my @post=<POST>;

close POST or die "Unable to close $filename $!";

my $first=0;
my $header=join '',grep {(not $first++)..(/^$/)} @post;
my $body =join '',grep {(/^$/)..(undef)} @post;

print PGP $body;

close PGP or die "Unable to open pgp $!";

open POST,">$filename" or die "Unable to open $filename $!";
open SIGNED,"</tmp/$$.$^T.pgp.output";

print POST $header;
print POST <SIGNED>;

close POST or die "Unable to close $filename $!";

