#!/usr/bin/perl -w

use strict;

# Take in the file name, check it and then if neccery post off a
# newgroup or rmgroup message.
sub checkmessage ( $ );

# Take in the file name and post off a newgroup or rmgroup message
sub makemessage ( $$ );

my $votedir = "vote";
my $vote = $ARGV[0];
my $now = time;

for my $file ("post.real","post.fake.phill","post.fake.robert") {
  checkmessage $file;
}

sub read1line {
  my($path) = @_;
  my($line);
  if (!open(F, $path)) {
    return "";
  }
  chop($line = <F>);
  close(F);
  return $line;
}

sub checkmessage ( $ ) {
  my $file = shift;
  local *FILE,*POST;
  
  if (not open FILE,"<vote/$vote/$file") {
    warn "Unable to open file $file $!\n";
    return;
  }
  
  if (not open (POST,">>/tmp/$file")) {
    next;
  }
  
  while (<FILE>) {
    my ($group,$firstpostdate,$intervil,$count)=split /\t/;
    
    if ($now>$firstpostdate) {
      makemessage $group,$file;
      
      $count--;
      if ($count) {
	
	$firstpostdate += $intervil;
	
	print POST "$group\t$firstpostdate\t$intervil\t$count\n";
	close POST;
      }
      
    } else {
      print POST $_;
    }
    
  }
  
  system "mv /tmp/$file vote/$vote/$file";
}

sub makemessage ( $$ ) {
  my $file=shift;
  my $name=shift;
  
  # This will be changed to code that works out weather or not I wish to newgroup
  # or rmgroup.
  my $newgroup=1;
  my $moderated=0;
  
  #Get the from line for the forging/setting for the from and apporved lines
  #should most likely be read from a file, just sticking it here while I deside
  #where it should go.
  my $from = {
	      "post.real" => "Aus news admin <ausadmin\@aus.news-admin.org>",
	      "post.fake.phill" => "Phil Herring <revdoc\@uow.edu.au>",
	      "post.fake.robert" => "kre\@munnari.OZ.AU (Robert Elz)",
	     } -> {$file};
  my $post;

  if ($newgroup) {
    if (not $moderated) {
      
      my $ngline = read1line("vote/$vote/ngline");
      my $charter = readfile("vote/$vote/charter");
      $post =<<"EOT";
From: $from
Subject: Cmsg newgroup $name
Newsgroup: aus.news,$name
Control: Newgroup $name
      
$name is an unmoderated newsgroup wich passed its vote for creation as reported
in aus.news
	  
For your newsgroups File:
$ngline
	    
This charter culled from the vote result announcement.
$charter
EOT

    } else {
# Do stuff for moderated group  
  }} else {
# Do stuff for rmgroup
  }

  if ($name =~ /forged/) {
    $post .= "\nThis control message has been forged as \"$from\" for the benifit of thouse\nsites still honouring his posts.  If you are one of thouse sites please see \<URL:http://aus.news-admin.org/\>.";
  }
  local *NEWS;
  if (not open (NEWS,"|pgpverify|inews -h")) {
    print "Unable to fork for pgpverify due to $!\n";
    exit (4);
  }
  
  print NEWS $post;

  if (not close NEWS) {
    print "Unabel to run pgpverify due to $!\n";
    exit (5);
  } 
}
