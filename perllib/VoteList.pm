#!/usr/bin/perl -w
#	@(#) $Header$

package VoteList;

use strict;

use Carp qw(confess);
use Vote qw();

sub new {
	my $class = shift;
	my $self = { @_ };

	$self->{vote_dir} || confess "Need vote_dir";

	bless $self, $class;
}

# This is the list of vote states which represent a running vote

my $stateSets = {
	'runningVotes' => {
		'vote/running' => 1,
	},
	'activeProposals' => {
		'rfd/posted' => 1,
	},

};

# Return a list of Vote() objects representing some set of states
# as defined in the argument

sub voteList {
	my $self = shift;
	my $stateset = shift;

	my $vote_dir = $self->{vote_dir} || confess "No vote_dir";

	my $states_ref = $stateSets->{$stateset} || confess "Unknown stateSet $stateset";

	opendir(DIR, $vote_dir) || die "Unable to opendir $vote_dir";

	my @files = grep { ! /^\./ } (readdir DIR);

	# Now collect only the subset representing running votes
	my @result;

	foreach my $f (sort @files) {
		my $v = new Vote(vote_dir => $vote_dir, name => $f);
		next if (!defined $v);

		my $state = $v->state();
		push(@result, $v) if ($states_ref->{$state});
	}

	return @result;
}

1;
