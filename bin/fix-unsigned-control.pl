#!/usr/bin/perl
#	@(#) $Id$
#
# fix-unsigned-control.pl: Find directories which contain control.msg
# but not control.signed and offer to sign them...


chdir($ENV{AUSADMIN_HOME});

foreach my $dir (<vote/*>) {
	next if (!-f "$dir/control.msg");
	next if (-f "$dir/control.signed");

	my $vote = $dir;
	$vote =~ s,^vote/,,;

	print "No signed control msg: $vote\n";
	my $rc = system("signcontrol < $dir/control.msg > $dir/control.signed");
	if ($rc != 0) {
		print STDERR "Unlinked $dir/control.signed due to error\n";
		unlink("$dir/control.signed");
	}
}

exit(0);
