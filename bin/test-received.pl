#!/usr/bin/perl
#	@(#) test-received.pl
#
# $Source$
# $Revision$
# $Date$


=head1 NAME
 test-received.pl - Show all the info we acquire from Received: headers

=cut

use lib 'bin';
use Message;

foreach my $path (@ARGV) {
	my $f = new Message();
	$f->parse_file($path);
	my @headers = $f->headers();

	foreach my $hdr (@headers) {
		next unless ($hdr =~ /^Received: /);
		my $data_hash = $f->check_received($hdr);
		$f->print_received_data($data_hash);
	}
}

exit(0);
