#!/usr/bin/perl -w
# $Revision$
# $Date$

use strict;
require "bin/misc.pli";

open SCHED,"<~/schedule" or die "Unable to open schedule.";
open POST,">/tmp/schedule.$$.$^T" or die "Unable to create schedule.";

while (<SCHED>) {
     my ($group,$firstpostdate,$interval,$count)=split /\t/;
     
     if ($now>$firstpostdate) {
	  sendmessage $group;
	  
	  $count--;
	  if ($count) {
	       
	       $firstpostdate += $interval;
	       
	       print POST "$group\t$firstpostdate\t$interval\t$count\n";
	  }
	  
     } else {
	  print POST $_;
     }     
}

close POST;


system "mv /tmp/schedule.$$.$^T ~/schedule";

sub sendmessage {
  my $filename=shift;
  system "cat $filename|signcontrol|rnews -";
}
