#!/usr/bin/perl
#	@(#) $Header$

open(INFILE, "<../data/control") || die "Can't open control: $!";
open(OUTFILE, ">../data/hier.txt") || die "Can't open hier.txt: $!";
undef $grouptitle;
undef @groups;
undef $groupcontact;
undef $contactpgp;
undef $groupurl;

while (<INFILE>) { chop;
	$line=$_;
	if ($line eq '') {
		if (@groups) {
			print OUTFILE "Title: $grouptitle\n" if ($grouptitle);
			print OUTFILE "Groups: @groups\n";
			print OUTFILE "Contact: $groupcontact\n" if ($groupcontact);
			print OUTFILE "Fingerprint: $contactpgp\n" if ($contactpgp);
			print OUTFILE "URL: $groupurl\n" if ($groupurl);
			print OUTFILE "SyncServer: $syncserver\n" if ($syncserver);
			print OUTFILE "PGP: ", ($grouppgp == 1) ? "yes" : "no", "\n";
			print OUTFILE "\n";
		}
		undef $grouptitle;
		undef @groups;
		undef $groupcontact;
		undef $contactpgp;
		undef $groupurl;
		undef $syncserver;
		undef $grouppgp;
		next;
	} elsif ($line =~ /## (.*)/) {
		$grouptitle = $1 unless ($grouptitle);
	} elsif ($line =~ /# \w*/) {
		$line =~ s/# //;
		if ($line =~ /Key fingerprint = (.*)/) {
			$contactpgp = $1;
			$grouppgp = 1;
			next;
		} elsif ($line =~ /\*PGP\*/) {
			$grouppgp = 1
		} elsif ($line =~ /(\w*): (.*)/) {
			$key = $1;
			$data = $2;
			if ($key eq 'Contact') {
				$groupcontact=$data;
				if ($groupcontact =~ /([\w-._]+\@[\w-._]+)/) {
					$groupcontact = $1;
					$groupcontact =~ tr/[A-Z]/[a-z]/;
				} else { undef $groupcontact }
				next;
			} elsif ($key eq 'URL') {
				$groupurl=$data;
				next;
			}
		} elsif ($line =~ 'Syncable Server: (.*)') {
			$syncserver = $1;
			next;
		}
	} elsif ($line =~ /\w+:\w+/) {
		($message, $from, $groups, $action)=split(":", $line);
		foreach (split(/\|/, $groups)) {
			if ($_ eq '*') { next }
			if ($action =~ /drop/) { next }
			push @groups, $_ unless (&isinre($_, @groups));
		}
	}
}
close(OUTFILE);
close(INFILE);

sub isin($var, @list) {
	my($var, @list)=@_;
	foreach (@list) { if ($var eq $_) { return 1 } }
	return 0;
}

sub isinre($var, @list) {
	my($var, @list)=@_;
	foreach (@list) {
		if ($_ =~ /.*$var.*/) { return 1 }
		if ($var =~ /.*$_.*/) { return 1 }
	}
	return 0;
}
