#!/usr/bin/perl
#	@(#) fix-tally-path.pl
# $Source$
# $Revision$
# $Date$

=head1 NAME

fix-tally-path.pl - Add missing pathnames into tally file

=head1 SYNOPSIS

bin/incoming.pl was changed sometime in 1998 and the change broke
the passing of filenames through to collater.pl. This program looks
through the B<messages> directory and all B<vote/*/tally.dat> files
and adds pathnames where it can.

=cut

use Time::Local;

my %message_path;

foreach my $path (<messages/*[0-9]>) {
	if ($path =~ m,^messages/(\d\d\d\d)(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d),) {
		# Find the timestamp
		my($year,$mon,$mday,$hour,$min,$sec) = ($1,$2,$3,$4,$5,$6);
		my $ts = timelocal($sec,$min,$hour,$mday,$mon-1,$year-1900);

		if (exists $message_path{$ts}) {
			print "Timestamp $ts multiply-defined ... ignoring it\n";
			$message_path{$ts} = '';
			next;
		}

		$message_path{$ts} = $path;
	}
}

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
		my($email,$vote,$choice,$ts,$p) = split(/\s/);

		my $ts2 = $ts;
		if (!exists $message_path{$ts}) {
			# Try one second earlier
			$ts2--;
		}

		if ($p eq '' && exists $message_path{$ts2}) {
			if ($message_path{$ts2} eq '') {
				print "Note ... $ts2 in $path is uncertain.\n";
				push(@lines, $_);
			} else {
				$p = $message_path{$ts2};
				$changed++;
				push(@lines, "$email $vote $choice $ts $p");
			}
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
