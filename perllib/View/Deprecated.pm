#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
# A place for all the deprecated functions

package View::Deprecated;

sub output {
	my $lr = shift;

	foreach my $s (@$lr) {
		if ((ref $s) eq 'ARRAY') {
			output($s);
		} elsif ((ref $s) eq 'HASH') {
			print "<!-- unable to output a hashref -->";
		} elsif (!defined $s) {
			# undef
		} elsif (!ref $s) {
			print $s;
		} else {
			print "<!-- unknown reference -->";
		}
	}
}

1;
