#!/usr/bin/perl
#	@(#) todo - bring up a list of outstanding actions

=head1 NAME

todo - bring up a list of outstanding actions for newsgroups

=head1 SYNOPSIS

todo

=head1 DESCRIPTION

This program examines all newsgroup vote directories (B<vote/*>) and
decides whether the vote requires an action, based on the existence
and contents of the various vote control files.

No files are changed or created by this program.

=cut

use lib 'bin';
use Vote;

my %action_states = (
	'vote/running' => 'Wait for end of vote',
	'complete/resultnotposted' => '',
	'complete/pass' => '',
	'complete/result' => 'Do something with the result - pass or fail?',
	'cancelled' => '',
);

if (!-d "./vote") {
	die "No ./vote directory - cd?";
}

opendir(D, "./vote");
my @votes = grep { ! /^\./ } (readdir(D));
closedir(D);

foreach my $vote (@votes) {

	my $v = new Vote(name => $vote);

	if (!defined $v) {
		print "$vote ... not a vote\n";
		next;
	}

	my $state = $v->state();

	if (!exists $action_states{$state}) {
		print "$vote ... Unknown state $state\n";
		next;
	}

	my $a = $action_states{$state};
	if ($a ne '') {
		print "$vote ... $a ($state)\n";
	}
}

exit(0);
