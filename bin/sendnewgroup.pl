#!/usr/bin/perl -w
# $Revision$
# $Date$

use strict;
require "bin/misc.pli";

my $schedule=shift;
my $filename=shift;
my $now=time;

open SCHED,"<$schedule" or die "Unable to open schedule.";
open POST,">/tmp/schedule.$$.$^T" or die "Unable to create schedule.";

while (<SCHED>) {
     my ($group,$firstpostdate,$interval,$count)=split /\t/;
     
     if ($now>$firstpostdate) {
	  &sendmessage($group);
	  
	  $count--;
	  if ($count) {
	       
	       $firstpostdate += $interval;
	       &sendmessage($filename);

	       print POST "$group\t$firstpostdate\t$interval\t$count\n";
	  }
	  
     } else {
	  print POST $_;
     }     
}

close POST;


system "mv /tmp/schedule.$$.$^T $schedule";

sub sendmessage {
#  my $filename=shift;
  die "Newgroup message file $filename not made" if not -e $filename;
  if ($filename =~ /fake/) {
       system "cat $filename|rnews";
  } else {
       system "cat $filename|signcontrol|rnews";
  }
}
