#!/usr/bin/perl
#	@(#) $Header$
#
#	Include a file into our output

package Include;

use strict;

use Carp qw(confess);
use IO::File qw(O_RDONLY O_WRONLY O_APPEND O_CREAT O_EXCL);

sub html {
	my $file = shift;

	my $path = "$ENV{AUSADMIN_DATA}/Html/$file";

	if (!-f $path || ! -r _) {
		$path = "$ENV{AUSADMIN_WEB}/Html/$file";
	}

	if (!-f $path || ! -r _) {
		return undef;
	}

	my $fh = new IO::File($path, O_RDONLY);
	die("Unable to open $path : $!") if (!defined $fh);

	my @lines = <$fh>;

	$fh->close();

	return \@lines;
}

1;
