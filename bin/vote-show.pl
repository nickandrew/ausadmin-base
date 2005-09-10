#!/usr/bin/perl
#	@(#) vote-show.pl  - show the results of each vote

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

use Vote;

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

	my($results, $voters);
	my $res;

	eval {
		($results, $voters) = $v->count_votes();
		$res = $v->calc_result();
	};

	if ($@) {
		print "$@\n";
		next;
	}

	printf "%-20.20s  %4s  yes = %2d no = %2d abs = %2d forge = %2d inv = %2d\n",
		$vote,
		$res,
		$results->{yes},
		$results->{no},
		$results->{abstain},
		$results->{forge},
		$results->{informal};

	foreach my $r (sort { $a->[0] cmp $b->[0] } @$voters) {
		printf "\t%-30.30s %8s\n",
			$r->[0], $r->[1];
	}
}

exit(0);
