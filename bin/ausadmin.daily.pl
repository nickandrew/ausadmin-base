#!/usr/bin/perl -w
#
# $Source$
# $Revision$
# $Date$

use strict;
use Getopt::Std;
use vars '$opt_d';


getopts("d");

my $debug=$opt_d;

chdir '/virt/web/ausadmin/';

sub endtime {
     local *FILE;
     
     my $filename=shift;
     my ($path,$vote,$name)=m{(.*)/([^/]*)/(.*)}g;
     
     open FILE,"<$filename" or die "Unable to open $filename due to $!";
     
     my $endtime=<FILE>;
     chomp $endtime;

     if (time>$endtime and not -e "$path/$vote/result") {
	  if ($debug) {
	       warn ("genresult.pl $vote >$path/$vote/result\n");
	       warn ("bin/post.pl < $path/$vote/result\n");
	       
	  } else {	       
	       system ("bin/genresult.pl $vote >$path/$vote/result");
	       system ("bin/post.pl < $path/$vote/result");
	  }
     }
}

sub realpost {
     local *FILE;
     
     my $filename=shift;
     my ($path,$vote,$name)=m{(.*)/([^/]*)/(.*)}g;
     
     if (-e "$path/$vote/newgroup.post.real") {
	  if ($debug) {
	       warn "sendnewgroup.pl $path/$vote/$name $path/$vote/newgroup.post.real\n";
	  } else {
	       system ("bin/sendnewgroup.pl $path/$vote/$name $path/$vote/newgroup.post.real");
	  }
	  
     }
}

sub fakepost_phil {
     local *FILE;
     
     my $filename=shift;
     my ($path,$vote,$name)=m{(.*)/([^/]*)/(.*)}g;

     if (-e "$path/$vote/newgroup.post.fake.phil") {
	  if ($debug) {
	       warn ("sendnewgroup.pl $path/$vote/$name $path/$vote/newgroup.post.fake.phil\n");
	  } else {
	       system ("bin/sendnewgroup.pl $path/$vote/$name $path/$vote/newgroup.post.fake.phil");
	  }
     }
     
}

sub fakepost_robert {
     local *FILE;
     
     my $filename=shift;
     my ($path,$vote,$name)=m{(.*)/([^/]*)/(.*)}g;

     if (-e "$path/$vote/newgroup.post.fake.robert") {
	  if ($debug) {
	       warn ("sendnewgroup.pl $path/$vote/$name $path/$vote/newgroup.post.fake.robert\n");
	  } else {
	       system ("bin/sendnewgroup.pl $path/$vote/$name $path/$vote/newgroup.post.fake.robert");
	  }

     }
}

sub creategroup {
     local *FILE;
     
     
     my $filename=shift;
     my ($path,$vote,$name)=m{(.*)/([^/]*)/(.*)}g;
     
     
     open FILE,"<$filename" or die "Unable to open $filename due to $!";
     
     my $endtime=<FILE>;
     chomp $endtime;
     
     if (time>$endtime) {
	  if ($debug) {
	       warn ("gennewgroup.pl $vote\n");
	       
	  } else {	       
	       system ("bin/gennewgroup.pl $vote");
	  }
     }
}


#This hash maps files to what action should be done on that file.

my $action = {
	      "endtime.cfg" => \&endtime,
	      "post.real" => \&realpost,
	      "post.fake.phil" => \&fakepost_phil,
	      "post.fake.robert" => \&fakepost_robert,
	      "group.creation.date" => \&creategroup,
	     };
     
#Get all the file names under the vote hyraky

open FIND,'find /virt/web/ausadmin/vote/ -type f|'
     or die "Can't fork for find because $!";

while (<FIND>) {
     #Hive off file names.
     my ($filename)=m{.*/(.*)}g;
     #Don't die If you can't find the right one.
     eval {	  
	  $action->{$filename}->($_) if (exists $action->{$filename});
     };
     
     warn $@ if ($@ and $@ !~ /Can\'t use string|uninitialized/);
}


close FIND or die "Find died $!";

