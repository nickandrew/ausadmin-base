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

if (!-d "./vote") {
	die "No ./vote directory - cd?";
}

opendir(D, "./vote");
my @votes = grep { ! /^\./ } (readdir(D));
closedir(D);

foreach my $vote (@votes) {
	my $d = "vote/$vote";

	# Needs rfd if ...?
	if (0) {
	my $ok = 1;
	foreach my $rfd_file (qw/rfd charter distribution ngline proposer rationale/) {
		if (!-f "$d/$rfd_file") {
			$ok = 0;
			print "$vote ... needs an rfd (new-rfd $vote rfd-file) ... missing $rfd_file\n";
			next;
		}

		if (!$ok) {
			print "$vote ... is stuffed.\n";
			next;
		}
	}
    }

	if (!-f "$d/rfd") {
		print "$vote ... needs an rfd (new-rfd $vote rfd-file)\n";
		next;
	}

	if (!-f "$d/vote_start.cfg") {
		# Vote not started, check if it's too early

		my $now = time();
		my $rfd_date = (stat("$d/rfd"))[9];
		next if ($now - $rfd_date < 21 * 86400);
		print "$vote ... ready to start vote when proponent requests\n";
		next;
	}

	# Check if CFV posted
	if (!-f "$d/posted.cfg") {
		print "$vote ... no posted.cfg, so please post the CFV\n";
		next;
	}

	# Check if vote cancelled
	if (-f "$d/vote_cancel.cfg") {
		# Check if cancel messages were created
		if (!-f "$d/cancel-article.txt") {
			print "$vote ... cancelled, but no cancel article\n";
			next;
		}

		if (!-f "$d/cancel-email.txt") {
			print "$vote ... cancelled, but no cancel email\n";
			next;
		}

		# Otherwise it is cancelled properly, nothing to do
		next;
	}

	if (!-f "$d/endtime.cfg") {
		print "$vote ... vote not setup properly, no endtime.cfg\n";
		next;
	}

	open(F, "<$d/endtime.cfg");
	my $end_time = <F>;
	chomp($end_time);

	if (time() < $end_time) {
		# Vote still running
		next;
	}

	# Vote ended, check results and etc
	if (!-f "$d/result") {
		print "$vote ... vote ended, but no result file\n";
	}

	# There's no programmatic way for us to tell whether a vote
	# passed or failed. So ignore here.
}

exit(0);
