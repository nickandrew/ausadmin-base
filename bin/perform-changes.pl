#!/usr/bin/perl

use lib 'bin';

use Ausadmin;
use Vote;
use Newsgroup;

my $vote = shift @ARGV || usage();

my $v = new Vote(name => $vote);
my $change_lr = $v->read_file('change');

# Process the changes a paragraph at a time

my @change_list;
my $hr = { };

foreach (@$change_lr) {
	chomp;
	if (/^$/) {
		if (%$hr) {
			push(@change_list, $hr);
			$hr = { };
		}
		next;
	} 

	# Otherwise ...
	my($k,$v) = ($_ =~ /^([^:]+):\s+(.*)/);
	if ($k ne '') {
		$hr->{$k} = $v;
	}
}

if (%$hr) {
	push(@change_list, $hr);
}

# Now go through each change ...
my $ct_map = {
	'moderate' => \&do_control,
	'unmoderate' => \&do_control,
	'charter' => \&do_charter,
	'newgroup' => \&do_control,
	'rmgroup' => \&do_control,
};

foreach my $c_hr (@change_list) {
	print STDERR "Change type: $c_hr->{type}\n";

	my $type = $c_hr->{type};

	if (exists $ct_map->{$type}) {

		my $coderef = $ct_map->{$type};
		&$coderef($v, $c_hr);
	} else {
		die "Unknown change type: $type\n";
	}
}

exit(0);

sub usage {
	die "Usage: perform-changes.pl vote-name\n";
}

sub do_charter {
	my $v = shift;
	my $c_hr = shift;

	my $newsgroup = $c_hr->{newsgroup};
	my $new_charter = $v->read_file("charter:$newsgroup");
	my $new_charter_string;
	foreach (@$new_charter) {
		$new_charter_string .= $_;
	}

	if ($new_charter ne '') {
		# Set the new charter
		my $ng = new Newsgroup(name => $newsgroup, datadir => "data/Newsgroups");
		$ng->set_attr('charter', $new_charter_string, "perform-changes.pl replaced charter");
	}
}

sub do_control {
	my $v = shift;
	my $change_hr = shift;
	my $type = 'post.real';		# KLUDGE ... force non-forged msgs only

	my $vote = $v->{name};

	my $text = make_control($type, $vote, $change_hr);
	my $vote_dir = $v->ng_dir();
	my $control_path = "$vote_dir/control.msg";

	if (-f $control_path) {
		# KLUDGE ... race condition!
		my $index = 1;
		while (-f $control_path) {
			$index++;
			$control_path = "$vote_dir/control$index.msg";
		}
	}

	if (!open(CF, ">$control_path")) {
		die "Unable to open $control_path for write: $!";
	}

	print CF $text;

	close(CF);

	$v->audit("Wrote control message($change_hr->{type}, $type, $vote) into $control_path");
}

sub make_control {
	my $type = shift;
	my $vote = shift;
	my $change_hr = shift;

	my $newgroup = 0;
	my $rmgroup = 0;
	my $moderated = 0;

	if ($change_hr->{type} =~ /^(moderate|unmoderate|newgroup)$/) {
		$newgroup = 1;
		$rmgroup = 0;
	}

	if ($change_hr->{type} =~ /^(rmgroup)$/) {
		$newgroup = 0;
		$rmgroup = 1;
	}

	if ($change_hr->{mod_status} eq 'm') {
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
	} elsif ($rmgroup) {
		$post = dormgroup($from,$vote);
	} else {
		die "not newgroup and not rmgroup - eh?";
	}

	return $post;
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

