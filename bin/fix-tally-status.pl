#!/usr/bin/perl
#	@(#) fix-tally-status.pl
#
# $Source$
# $Revision$
# $Date$

=head1 NAME

fix-tally-status.pl - Add a status field to missing tally.dat lines

=head1 SYNOPSIS

tally.dat line format is being changed to add a vote-checking status.
The default will be "NEW", so go through all B<tally.dat> files and
add this field at the end, if it does not exist already.

=cut

# Now read each of the tally files, and replace if we can update it

foreach my $path (<vote/*/tally.dat>) {
	if (!open(F, "<$path")) {
		print "Unable to open $path for read: $!\n";
		next;
	}

	my @lines;
	my $changed = 0;

	while (<F>) {
		chomp;
		my($email,$vote,$choice,$ts,$p,$status) = split(/\s/);

		if ($status eq '') {
			push(@lines, "$email $vote $choice $ts $p NEW");
			$changed++;
		} else {
			push(@lines, $_);
		}
	}

	close(F);

	if ($changed) {
		if (!open(G, ">$path.new")) {
			print "Unable to open $path.new for write: $!\n";
			next;
		}

		foreach (@lines) {
			print G $_, "\n";
		}

		close(G);
		rename($path, "$path.old");
		rename("$path.new", $path);
		print "Updated $path with $changed changes\n";
	}
}

exit(0);
