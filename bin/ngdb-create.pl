#!/usr/bin/perl

if (!-d "vote") {
	die "Need to be in top-level ausadmin directory";
}

while (<STDIN>) {
	chomp;
	my($n,$d) = ($_ =~ /^(\S+)\s+(.*)/);
	if($n ne '') {
		my $d = "data/Newsgroups/$n";

		if (!-d $d) {
			mkdir "$d", 0755;
			mkdir "$d/RCS", 0755;
		}

		my $ngline = "$d/ngline";
		if (!-f $ngline) {
			if (!open(T, ">$ngline")) {
				print STDERR "Unable to open $n/ngline: $!\n";
			} else {
				print T $d, "\n";
				close(T);
			}
		}

		if (!-f "$d/charter") {
			if (-f "data/Charters/$n") {
				rename("data/Charters/$n", "data/Newsgroups/$n/charter");
			} elsif (-f "root/Charters/$n") {
				system("cp root/Charters/$n data/Newsgroups/$n/charter");
			}
		}

		if (-f "$d/charter" && !-f "$d/RCS/charter,v") {
			system("ci -l $d/charter -t- < /dev/null");
		}

		if (-f "$d/ngline" && !-f "$d/RCS/ngline,v") {
			system("ci -l $d/ngline -t- < /dev/null");
		}

	}
}

exit(0);
