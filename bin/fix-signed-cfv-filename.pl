#!/usr/bin/perl
#	@(#) $Id$
#
#	Rename all "posted.cfv" files to "cfv.signed" in all votes

if (! -d './vote') {
	die "No vote subdirectory (cd $ENV{AUSADMIN_HOME} ?)\n";
}

foreach my $dir (<vote/*>) {
	if (-f "$dir/posted.cfv" && !-f "$dir/cfv.signed") {
		rename("$dir/posted.cfv", "$dir/cfv.signed");
		print "Renamed $dir/posted.cfv\n";
	}
}

exit(0);
