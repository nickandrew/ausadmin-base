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

use lib 'bin';
use Ausadmin;

my $vote = shift @ARGV;
my $ng_dir = "vote/$vote";

die "No directory $ng_dir" if (!-d $ng_dir);
# die "There is already a file $control_file" if (-s $control_file);

# KLUDGE ... This assumes only one change per proposal
my $change = Ausadmin::read_list_keyed_file("$ng_dir/change");
# change->{type} ...
#	newgroup, rmgroup, moderate, unmoderate, charter

foreach my $changelet (@$change) {
	my $type = $changelet->{type};
	my $ng = $changelet->{newsgroup};

	if ($type =~ /^(newgroup|rmgroup|moderate|unmoderate)$/) {
		make_control("post.real", $vote, $changelet);
	} elsif ($type eq 'charter') {
		print STDERR "Unable to handle charter change requests.\n";
	} else {
		print STDERR "Unknown change type: $type\n";
	}
}
	
exit(0);

sub make_control {
	my $type=shift;
	my $vote=shift;
	my $changelet = shift;

# This will be changed to code that works out whether or not I wish to newgroup
# or rmgroup.
	my $newgroup = 1;
	my $moderated = 0;

	if ($changelet->{type} =~ /^(moderate|unmoderate|newgroup)$/) {
		$newgroup = 1;
	}

	if ($changelet->{type} =~ /^(rmgroup)$/) {
		$newgroup = 0;
	}

	if ($changelet->{mod_status} eq 'm') {
		$moderated = 1;
	}

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
		$post = dormgroup($from,$vote);
	}

	print $post;

#	if (!open(FILE, ">$file")) {
#		die "Unable to open $file: $!";
#	}

#	print FILE $post;
#	close(FILE);
}

sub donewgroup {
	my $moderated = shift;
	my $from = shift;
	my $vote = shift;

	my $name = $vote;		# KLUDGE

	my $ngline = Ausadmin::read1line("vote/$vote/ngline:$name");
	my $charter = Ausadmin::readfile("vote/$vote/charter:$name");
	my $control;
	my $modname;

	if ($moderated) {
		$control = "newgroup $name m";
		$modname = "a moderated";
	} else {
		$control = "newgroup $name";
		$modname = "an unmoderated";
	}


	my $post = <<"EOF";
From: $from
Subject: Cmsg newgroup $name
Newsgroups: aus.net.news,$name
Control: $control
Approved: $from


$name is $modname newsgroup which passed its vote for
creation as reported in aus.net.news.  For full information, see:

	http://aus.news-admin.org/cgi-bin/voteinfo?newsgroup=$vote

For your newsgroups file:
$ngline

CHARTER: $name

$charter
END CHARTER.

EOF

	return $post;
}

sub dormgroup {
	my $from = shift;
	my $vote = shift;

	my $name = $vote;		# KLUDGE

	my $control = "rmgroup $name";
	my $modname;

	my $post = <<"EOF";
From: $from
Subject: Cmsg rmgroup $name
Newsgroups: aus.net.news,$name
Control: $control
Approved: $from


ausadmin requests removal of group $name as reported in aus.net.news.
For full information, see:

	http://aus.news-admin.org/cgi-bin/voteinfo?newsgroup=$vote
EOF

	return $post;
}
