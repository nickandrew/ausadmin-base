#!/usr/bin/perl
#	@(#) $Header$
#
#	Display an up-to-the-moment summary of voting

use lib 'bin';

use Vote qw();

my @vote_list = Vote::list_votes(vote_dir => "vote");

foreach my $vote_name (sort @vote_list) {
	my $v = new Vote(name => $vote_name);
	my $state = $v->state();

	if ($state ne 'vote/running') {
#		print "Ignoring $vote_name - state is $state\n";
		next;
	}

	my $tally = $v->get_tally();
	my %choices;

	$choices{'YES'} = 0;
	$choices{'NO'} = 0;
	$choices{'ABSTAIN'} = 0;

	foreach my $r (@$tally) {
		$choices{$r->{vote}} ++;
	}

	printf "%-30.30s ", $vote_name;
	foreach my $k (sort (keys %choices)) {
		printf "%s = %d ", $k, $choices{$k};
	}
	print "\n";
}

exit(0);
