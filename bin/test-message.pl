#!/usr/bin/perl
#	@(#) test-message.pl - Test the Message class

=head1 NAME

test-message.pl - Test the Message class

=head1 SYNOPSIS

test-message.pl [-h] filename ...

-h : Print headers as message is read

=cut

use Getopt::Std;
use lib 'bin';
use Message;

my %opts;

getopts('h', \%opts);

foreach my $path (@ARGV) {
	my $m = new Message();
	$m->parse_file($path);

	print "\nAnalysing: $path\n";

	if ($opts{'h'}) {
		$m->print_headers();
	}

	# Find the IP addresses in headers (webmail addresses etc)
	my $info_hr = $m->header_info();

	print "Results:\n";

	foreach my $k (sort (keys %$info_hr)) {
		my $r = $info_hr->{$k};
		print "$k: ";
		if (ref $r) {	
			print "@{$r}", "\n";
		} elsif (!defined $r) {
			print "duh\n";
		} else {
			print "$r\n";
		}
	}
}

exit(0);
