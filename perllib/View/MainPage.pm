#!/usr/bin/perl
#	@(#) $Header$

package View::MainPage;

use strict;

use VoteList qw();
use Include qw();

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

sub insideBody {
	my @contents;

	push(@contents, <<EOF);
<table width="600" cellpadding="0" cellspacing="0" border="0">
 <tr>
EOF

	push(@contents, leftColumn());
	push(@contents, rightColumn());

	push(@contents, <<EOF);
 </tr>
</table>
EOF

	return \@contents;
}

sub leftColumn {
	my @contents;

	push(@contents, <<EOF);
  <td bgcolor="#ffffe0" width="100" valign="top">
   <font size="-1">
EOF

	push(@contents, ausadminHeader());

	my $votelist = new VoteList(vote_dir => "$ENV{AUSADMIN_HOME}/vote");
	push(@contents, proposalList($votelist));
	push(@contents, runningVotesList($votelist));
	push(@contents, newsgroupList());

	push(@contents, <<EOF);
   </font>
  </td>
EOF

	return \@contents;
}

sub template {
	my @contents;
	push(@contents, <<EOF);
EOF
	push(@contents, <<EOF);
EOF
	return \@contents;
}

sub ausadminHeader {
	return Include::html('header-links.html');
}

sub proposalList {
	my $votelist = shift;
	my @contents;

	my @proposals = $votelist->voteList('activeProposals');

	if (! @proposals) {
		return undef;
	}

	push(@contents, <<EOF);
<!-- start of proposals -->
<p>
<b>Proposals:</b><br>
EOF

	foreach my $v (@proposals) {
		my $p = $v->getName();
		my $s = "&nbsp;&nbsp;<a href=\"/proposal.cgi?proposal=$p\">$p</a><br>\n";
		push(@contents, $s);
	}

	push(@contents, <<EOF);
</p>
<!-- end of proposals -->
EOF
	return \@contents;
}

sub runningVotesList {
	my $votelist = shift;
	my @contents;

	my @runningvotes = $votelist->voteList('runningVotes');

	if (! @runningvotes) {
		return undef;
	}

	push(@contents, <<EOF);
<!-- start of runningvotes -->
<p>
<b>Votes&nbsp;running:</b><br>
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

		my $s = "&nbsp;&nbsp;<a href=\"/proposal.cgi?proposal=$p\">$p (ends in $ends)</a><br>\n";
		push(@contents, $s);
	}

	push(@contents, <<EOF);
</p>
<!-- end of runningvotes -->
EOF

	return \@contents;
}

sub newsgroupList {
	my @contents;

	# Return an array of newsgroup names
	my @newsgrouplist = Newsgroup::list_newsgroups(datadir => "$ENV{AUSADMIN_DATA}");

	if (!@newsgrouplist) {
		return undef;
	}

	push(@contents, <<EOF);
<p>
<b>Newsgroups:</b><br>
EOF

	foreach my $g (@newsgrouplist) {
		my $s = "&nbsp;&nbsp;<a href=\"groupinfo.cgi/$g/\">$g</a><br>\n";
		push(@contents, $s);
	}

	push(@contents, <<EOF);
</p>
EOF
	return \@contents;
}

sub rightColumn {
	my @contents;
	push(@contents, <<EOF);
  <!-- Next column -->
  <td valign="top">
EOF
	push(@contents, ausadminHeading());
	push(@contents, ausadminContents());

	push(@contents, <<EOF);
  </td>
  <!-- end of right column -->
EOF
	return \@contents;
}

sub ausadminHeading {
	my @contents;
	my $hier = $ENV{AUSADMIN_HIER} || 'aus';

	push(@contents, <<EOF);
   <center>
    <h1>
     <font face=sans-serif>$hier Newsgroup Administration</font>
    </h1>
   </center>
EOF
	return \@contents;
}

sub ausadminContents {
	my @contents;
	my $hier = $ENV{AUSADMIN_HIER} || 'aus';

	push(@contents, <<EOF);
   <table cellpadding=5 cellspacing=0 width=100% border=0>
EOF
	push(@contents, ausadminSubHeadingRow("Overview"));
	push(@contents, Include::html('overview.html'));
	push(@contents, ausadminSubHeadingRow("ausadmin Role"));
	push(@contents, Include::html('role.html'));
	push(@contents, ausadminSubHeadingRow("$hier structure planning"));
	push(@contents, Include::html('structure.html'));
	push(@contents, ausadminSubHeadingRow("ausadmin Policy"));
	push(@contents, Include::html('policy.html'));
	push(@contents, ausadminSubHeadingRow("Links"));
	push(@contents, Include::html('links.html'));
	push(@contents, ausadminSubHeadingRow("Newsgroup Creation Proposals"));
	push(@contents, Include::html('proposals.html'));
	push(@contents, <<EOF);
   </table>
EOF
	return \@contents;
}

sub ausadminSubHeadingRow {
	my $string = shift;

	my @contents;
	push(@contents, <<EOF);

    <tr bgcolor="#000000">
     <td>
      <font size=+1 color="#66cc66" face=sans-serif><b>$string</b></font>
     </td>
    </tr>
EOF
	return \@contents;
}

1;
