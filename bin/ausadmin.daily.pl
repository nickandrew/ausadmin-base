#!/usr/bin/perl -w

use strict;
use Getopt::Std;
use vars '$opt_d';

#This hash maps files to what action should be done on that file.

getopts("d");

my $debug=$opt_d;

chdir 'find /virt/web/ausadmin/';

sub endtime {
     local *FILE;
     
     my $filename=shift;
     my ($path,$vote,$name)=m{(.*)/([^/]*)/(.*)}g;
     
     open FILE,"<$filename" or die "Unable to open $filename due to $!";
     
     my $endtime=<FILE>;
     if (time>$endtime and not -e "$path/$vote/result") {
	  if ($debug) {
	       warn ("genresult.pl $vote >$path/$vote/result\n");
	       warn ("inews -h $path/$vote/result\n");
	       
	  } else {	       
	       system ("genresult.pl $vote >$path/$vote/result");
	       system ("inews -h $path/$vote/result");	       
	  }
     }
}

sub realpost {
     local *FILE;
     
     my $filename=shift;
     my ($path,$vote,$name)=m{(.*)/([^/]*)/(.*)}g;
     
     if ($debug) {
	  warn "sendnewgroup.pl $path/$vote/$name $path/$vote/newgroup.post.real\n";
     } else {
	  system ("sendnewgroup.pl $path/$vote/$name $path/$vote/newgroup.post.real");
     }
     
}

sub fakepost_phil {
     local *FILE;
     
     my $filename=shift;
     my ($path,$vote,$name)=m{(.*)/([^/]*)/(.*)}g;

     if (-e "newgroup.post.fake.phil") {
	  if ($debug) {
	       warn ("sendnewgroup.pl $path/$vote/$name $path/$vote/newgroup.post.fake.phil\n");
	  } else {
	       system ("sendnewgroup.pl $path/$vote/$name $path/$vote/newgroup.post.fake.phil");
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
	       system ("sendnewgroup.pl $path/$vote/$name $path/$vote/newgroup.post.fake.robert");
	  }

     }
}


my $action = {
	      "endtime.cfg" => \&endtime,
	      "post.real" => \&realpost,
	      "post.fake.phil" => \&fakepost_phil,
	      "post.fake.robert" => \&fakepost_robert,
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

