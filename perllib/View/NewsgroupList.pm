#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#	A list of newsgroups in the hierarchy

package View::NewsgroupList;

use strict;
use base 'Contained';

sub html {
	my $self = shift;

	my @contents;

	# Return an array of newsgroup names
	my @newsgrouplist = Newsgroup::list_newsgroups(datadir => "$ENV{AUSADMIN_DATA}");

	if (!@newsgrouplist) {
		return '';
	}

	my $uri_prefix = $self->{vars}->{URI_PREFIX};

	push(@contents, <<EOF);
<p>
<b>Newsgroups:</b><br />
EOF

	foreach my $g (@newsgrouplist) {
		my $s = qq{&nbsp;&nbsp;<a href="$uri_prefix/groupinfo.cgi/$g">$g</a><br />\n};
		push(@contents, $s);
	}

	push(@contents, <<EOF);
</p>
EOF
	return join('', @contents);
}

1;
