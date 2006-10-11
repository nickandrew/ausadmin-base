#!/usr/bin/perl -w

print "Content-Type: text/plain\n\n";

my @test_paths = qw(
	/usr/bin/gpg
	/usr/bin/pgp
);

foreach my $k (sort (keys %ENV)) {
	printf "%-20s  => %s\n", $k, $ENV{$k};
}

print "\n";

foreach my $k (@INC) {
	printf "Inc: %s\n", $k;
}

# my @libs = qw(Socket IO::Handle CGI Net::Stuff);
my @libs = ();

foreach my $lib (@libs) {
	eval "use $lib";
	if ($@) {
		print "NO $lib\n";
	} else {
		print "$lib OK\n";
	}
}

print "\n";

foreach my $path (@test_paths) {
	if (! -f $path) {
		print "$path DOES NOT exist\n";
	}
	elsif (-x $path) {
		print "$path exists and is executable\n";
	}
	else {
		print "$path exists and IS NOT executable\n";
	}
}

exit(0);
