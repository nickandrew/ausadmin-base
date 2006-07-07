#!/usr/bin/perl -w

print "Content-Type: text/plain\n\n";

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

exit(0);
