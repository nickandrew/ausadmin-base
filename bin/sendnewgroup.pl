#!/usr/bin/perl -w
# $Revision$
# $Date$

use strict;
require "bin/misc.pli";

my $debug=0;
my $schedule=shift;
my $filename=shift;
my $now=time;

open SCHED,"<$schedule" or die "Unable to open schedule.";
open POST,">/tmp/schedule.$$.$^T" or die "Unable to create schedule.";

while (<SCHED>) {
     my ($group,$firstpostdate,$interval,$count)=split /\t/;

     die "firstnotset $schedule" unless $firstpostdate;

     if ($now>$firstpostdate) {
	  &sendmessage($filename);
	  
	  $count--;
	  if ($count) {
	       
	       $firstpostdate += $interval;
	       &sendmessage($filename);
	       if ($debug) {
		 print "$group\t$firstpostdate\t$interval\t$count\n";
	       } else {
		 print POST "$group\t$firstpostdate\t$interval\t$count\n";
	       }
	       
	  }
	  
     } else {
       if ($debug) {
	 print $_;
       } else {
	 print POST $_;
       }
	  
     }     
}

close POST;

if ($debug) {
  print "mv /tmp/schedule.$$.$^T $schedule";
} else {
  system "mv /tmp/schedule.$$.$^T $schedule";
}


sub sendmessage {
  #  my $filename=shift;
  die "Newgroup message file $filename not made" if not -e $filename;
  if ($debug) {
    print "cat $filename|rnews";
  } else {
    if ($filename =~ /fake/) {
      system "cat $filename|bin/rnews";
    } else {
      system "cat $filename|signcontrol|bin/rnews";
    }  
  }
  
}

__END__

=pod

=head1 NAME

sendnewgroup schedulefilename newsgroupfilename

=head1 SYNOPSIS

posts newsgroupfilename dependent on the schedule layed out in 
schedulefilename.  The format of this file is as followed.

groupnanme\tnextdate\tintervil\tcount

Where groupnanme is the name of the group (ignored present for backwards 
compatablity.

nextdate is the date when the next new group will be issued in seconds since 
epock

interval is the time between issueings in seconds.
=cut
