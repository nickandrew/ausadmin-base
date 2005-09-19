#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#	A View of a Proposal

package View::ProposalContents;

use strict;
use base 'Contained';

sub html {
	my $self = shift;

	my $vote = $self->{vote};

	my $rfd_text = $vote->read_file("rfd");

	return qq{<pre>@$rfd_text</pre>};
}

1;
