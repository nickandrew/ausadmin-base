#!/usr/bin/perl -w
#	@(#) gencontrol.pl vote
#
# $Source$
# $Revision$
# $Date$

=head1 NAME

gencontrol.pl - Generate control message (usually newgroup)

=head1 SYNOPSIS

gencontrol.pl newsgroup-name

=cut

use strict;
use Ausadmin;

# Take in the file name and post off a newgroup or rmgroup message
sub makemessage ( $$$ );

my $votedir = "vote";
my $vote = $ARGV[0];

my $ng_dir = "vote/$vote";
my $control_file = "vote/$vote/control.msg";

die "No directory $ng_dir" if (!-d $ng_dir);
die "There is already a file $control_file" if (-s $control_file);

# Otherwise make the message...
my $rc = makemessage($control_file, "post.real", $vote);

exit($rc);

sub makemessage ( $$$ ) {
	my $file=shift;
	my $type=shift;
	my $vote=shift;
     
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
	} -> {$type};

	my $post;

	if ($newgroup) {
		$post = donewgroup($moderated,$from,$vote);
	} else {
		die "rmgroup not defined!";
# Do stuff for rmgroup
	}

	open FILE,">$file" or die "Unable to open $file: $!";
	print FILE $post;
	close(FILE);
}

sub donewgroup {

	my ($moderated,$from,$vote) = @_;

	my $name = $vote;		# KLUDGE
	my $post;

	my $ngline = Ausadmin::read1line("vote/$vote/ngline");
	my $charter = Ausadmin::readfile("vote/$vote/charter");

	if (not $moderated) {
	  
		$post = <<"EOT";
From: $from
Subject: Cmsg newgroup $name
Newsgroups: aus.net.news,$name
Control: newgroup $name
Approved: $from


$name is an unmoderated newsgroup which passed its vote for creation
as reported in aus.net.news.  For full information, see:

	http://aus.news-admin.org/cgi-bin/voteinfo?newsgroup=$vote
	  
For your newsgroups file:
$ngline

CHARTER: $name
$charter
END CHARTER.

EOT
	} else {
		# Do stuff for moderated group  
		die "Unable to write newgroup control msg for moderated group";
	}
     
	return $post;
}
