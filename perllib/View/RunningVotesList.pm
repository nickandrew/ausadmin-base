#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#	Running Votes list

package View::RunningVotesList;

use strict;
use base 'Contained';


sub html {
	my $self = shift;

	my $votelist = $self->{container}->getVoteList();
	my @contents;

	my @runningvotes = $votelist->voteList('runningVotes');

	if (! @runningvotes) {
		return '';
	}

	push(@contents, <<EOF);
<!-- start of runningvotes -->
<p>
<b>Votes&nbsp;running:</b><br />
EOF

	my $now = time();

	foreach my $v (@runningvotes) {
		my $p = $v->getName();
		my $endtime = $v->get_end_time();

		if ($endtime < $now) {
			# Ignore it completely
			next;
		}

		my $ed = int(($endtime - $now)/86400);
		my $eh = int(($endtime - $now)/3600);
		my $em = int(($endtime - $now)/60);
		my $es = ($endtime - $now);

		my $ends = "$es seconds";
		$ends = "$em minutes" if ($em > 1);
		$ends = "$eh hours" if ($eh > 1);
		$ends = "$ed days" if ($ed > 1);

		my $s = "&nbsp;&nbsp;<a href=\"/proposal.cgi?proposal=$p\">$p (ends in $ends)</a><br />\n";
		push(@contents, $s);
	}

	push(@contents, <<EOF);
</p>
<!-- end of runningvotes -->
EOF

	return join('', @contents);
}

1;
