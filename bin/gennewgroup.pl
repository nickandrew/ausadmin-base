#!/usr/bin/perl
#	@(#) gennewgroup.pl vote
#
# $Source$
# $Revision$
# $Date$

die "This program is obsolete";

use strict;
use lib 'bin';
use Ausadmin;

# Take in the file name, check it and then if necessary post off a
# newgroup or rmgroup message.
sub checkmessage ( $ );

# Take in the file name and post off a newgroup or rmgroup message
sub makemessage ( $$ );

my $votedir = "vote";
my $vote = $ARGV[0];
my $now = time;

# die "Once only" if (-e "vote/$vote/once");

exit(0) if (-e "vote/$vote/once");

{
  local *ONCE;
  open *ONCE,">>vote/$vote/once";
  close *ONCE;
}

for my $file ("post.real","post.fake.phil","post.fake.robert") {
  checkmessage $file;
}

sub checkmessage ( $ ) {
  my $file = shift;
  local (*FILE,*POST);
  
  if (not open FILE,"<vote/$vote/$file") {
    warn "Unable to open file vote/$vote/$file $!\n";
    return;
  }
  
  if (not open (POST,">>/tmp/$file")) {
    next;
  }
  
  while (<FILE>) {
    my ($group,$firstpostdate,$interval,$count)=split /\t/;    
    makemessage($group,$file);      
  }
  
#  system "mv /tmp/$file vote/$vote/$file";
}

sub makemessage ( $$ ) {
     my $file=shift;
     my $name=shift;
     
# This will be changed to code that works out whether or not I wish to newgroup
# or rmgroup.
     my $newgroup=1;
     my $moderated=0;
     
#Get the from line for the forging/setting for the from and approved lines
#should most likely be read from a file, just sticking it here while I decide
#where it should go.

     my $from = {
		 "post.real" => "Aus news admin <ausadmin\@aus.news-admin.org>",
		 "post.fake.phil" => "Phil Herring <revdoc\@cs.uow.edu.au>",
		 "post.fake.robert" => "kre\@munnari.OZ.AU (Robert Elz)",
		} -> {$name};
     my $post;

     if ($newgroup) {
	  $post=&donewsgroup($moderated,$from,$file);
     } else {
# Do stuff for rmgroup
     }
     
     if ($name =~ /forged/) {
	  $post .= "\nThis control message has been forged as \"$from\" for the benefit of those\nsites still honouring his posts.  If you are one of those sites please see \<URL:http://aus.news-admin.org/\>.";
     }

     open FILE,">/home/ausadmin/vote/$vote/newgroup.$name" or die "Yipe Yipe Yipe unable to open /home/ausadmin/vote/$vote/newgroup.$name because $!\n";
     print FILE $post;
     
}

sub donewsgroup {

     my ($moderated,$from,$name)=@_;

     if (not $moderated) {
	  
	  my $ngline = Ausadmin::read1line("vote/$vote/ngline");
	  my $charter = Ausadmin::readfile("vote/$vote/charter");
	  my $post =<<"EOF";
From: $from
Subject: Cmsg newgroup $name
Newsgroups: aus.net.news,$name
Control: newgroup $name
Approved: $from


$name is an unmoderated newsgroup which passed its vote for creation as 
reported in aus.net.news
	  
For your newsgroups file:
$ngline

This charter culled from the vote result announcement.
$charter
EOF

	  local *GLIST;
	  open GLIST,">>data/ausgroups" or die "Can't open ausgroups.";
	  print GLIST $ngline,"\n";
	  close GLIST;

	  return $post;
     } else {
# Do stuff for moderated group  
     }
     
}
