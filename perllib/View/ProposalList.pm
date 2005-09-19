#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#	A list of proposals

package View::ProposalList;

use strict;

use base 'Contained';

sub html {
	my $self = shift;

	my $votelist = $self->{container}->getVoteList();
	my @contents;

	my @proposals = $votelist->voteList('activeProposals');

	if (! @proposals) {
		return '';
	}

	my $uri_prefix = $self->{vars}->{URI_PREFIX};

	push(@contents, <<EOF);
<!-- start of proposals -->
<p>
<b>Proposals:</b><br />
EOF

	foreach my $v (@proposals) {
		my $p = $v->getName();
		my $s = "&nbsp;&nbsp;<a href=\"$uri_prefix/proposal.cgi?proposal=$p\">$p</a><br />\n";
		push(@contents, $s);
	}

	push(@contents, <<EOF);
</p>
<!-- end of proposals -->
EOF
	return join('', @contents);
}

1;
