#!/usr/bin/perl
#	@(#) todo.pl - bring up a list of outstanding actions

=head1 NAME

todo.pl - bring up a list of outstanding actions for newsgroups

=head1 SYNOPSIS

todo.pl

=head1 DESCRIPTION

This program examines all newsgroup vote directories (B<vote/*>) and
decides whether the vote requires an action, based on the existence
and contents of the various vote control files.

No files are changed or created by this program.

=cut

use lib 'bin';
use Ausadmin;
use Vote;
use DateFunc;

my %action_states = (
	'vote/running' => 'Wait for end of vote',
	'complete/resultnotposted' => '',
	'complete/pass/signed' => 'Create and post newgroup message?',
	'complete/pass' => '',
	'complete/result' => 'Do something with the result - pass or fail?',
	'cancelled' => '',
	'new/norfd' => 'Use action to create the RFD',
	'rfd/unposted' => 'Use action to post the RFD',
	'rfd/posted' => 'In discussion, wait until ',
);

if (!-d "./vote") {
	die "No ./vote directory - cd?";
}

my $today = Ausadmin::today();

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

	if ($state eq 'rfd/posted') {
		my $config_path = $v->ng_dir("rfd_posted.cfg");
		open(F, "<$config_path");
		my $date = <F>;
		$date = DateFunc::addday($date, 21);
		chomp($date);
		close(F);
		$a .= $date;
		if ($date le $today) {
			$a = "Use action to abandon or post the CFV";
		}
	}

	if ($a ne '') {
		print "$vote ... $a ($state)\n";
	}
}

exit(0);
