#!/usr/bin/perl
#	@(#) clean up the vote directory
#	(i.e. modify it according to current vote directory standards)
#

if (! -d "vote/") {
	die "Need to be in ausadmin home directory (no vote/ subdir found)\n";
}

my $d = "./vote";

opendir(D, $d) or die "Unable to opendir($d) ... $!\n";
my @votes = grep { ! /^\./ } readdir(D);
closedir(D);

foreach my $vote (sort @votes) {
	# look for ngline files

	my $vd = "$d/$vote";
	my $ng = $vote;
	$ng =~ s/:.*//;

	if (-f "$vd/ngline" && ! -f "$vd/ngline:$ng") {
		print "mv $vd/ngline $vd/ngline\\:$ng\n";
	}

	if (-f "$vd/rfd" && ! -f "$vd/rationale") {
		print "Vote $vote has no rationale!\n";
	}

	if (-f "$vd/rfd" && ! -f "$vd/charter" && ! -f "$vd/charter:$ng") {
		print "Vote $vote has no charter file!\n";
	}

	if (-f "$vd/rfd" && -f "$vd/charter" && ! -f "$vd/charter:$ng") {
		print "mv $vd/charter $vd/charter\\:$ng\n";
	}
}

