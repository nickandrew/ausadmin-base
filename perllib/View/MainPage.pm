#!/usr/bin/perl
#	@(#) $Header$

package View::MainPage;

use strict;

use VoteList qw();

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
	my @contents;
	push(@contents, <<EOF);
<p>
<b>For&nbsp;USENET&nbsp;Users:</b><br>
&nbsp;&nbsp;<a href="/">ausadmin&nbsp;home</a><br>
&nbsp;&nbsp;<a href="/Faq/ausadmin.html">About&nbsp;ausadmin</a><br>
&nbsp;&nbsp;<a href="/Faq/aus_faq">Group&nbsp;creation&nbsp;FAQ</a><br>
</p>

<p>
<b>For&nbsp;Server&nbsp;Admins:</b><br>
&nbsp;&nbsp;<a href="/checkgroups.shtml">aus.*&nbsp;Checkgroups</a><br>
&nbsp;&nbsp;<a href="/ausadmin.asc">PGP public key</a><br>
&nbsp;&nbsp;<a href="/control.ctl">INN control.ctl</a><br>
</p>


<p>
<b>For&nbsp;Hierarchy&nbsp;Admins:</b><br>
&nbsp;&nbsp;<a href="http://www.nick-andrew.net/projects/ausadmin/">Download&nbsp;Software</a><br>
&nbsp;&nbsp;<a href="http://www.news-admin.org/">news-admin.org</a><br>
</p>

EOF
	return \@contents;
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
	my @grouplist = Newsgroup::list_newsgroups(datadir => "$ENV{AUSADMIN_DATA}/Newsgroups");

	if (!@grouplist) {
		return undef;
	}

	push(@contents, <<EOF);
<p>
<b>Newsgroups:</b><br>
EOF

	foreach my $g (@grouplist) {
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
	push(@contents, <<EOF);
   <center>
    <h1>
     <font face=sans-serif>aus.* Newsgroup Administration</font>
    </h1>
   </center>
EOF
	return \@contents;
}

sub ausadminContents {
	my @contents;
	push(@contents, <<EOF);
   <table cellpadding=5 cellspacing=0 width=100% border=0>
EOF
	push(@contents, ausadminSubHeadingRow("Overview"));
	push(@contents, ausadminOverviewRow());
	push(@contents, ausadminSubHeadingRow("ausadmin Role"));
	push(@contents, ausadminRoleRow());
	push(@contents, ausadminSubHeadingRow("aus.* structure planning"));
	push(@contents, ausadminStructureRow());
	push(@contents, ausadminSubHeadingRow("ausadmin Policy"));
	push(@contents, ausadminPolicyRow());
	push(@contents, ausadminSubHeadingRow("Links"));
	push(@contents, ausadminLinksRow());
	push(@contents, ausadminSubHeadingRow("Newsgroup Creation Proposals"));
	push(@contents, ausadminCreationProposalsRow());
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

sub ausadminOverviewRow {
	my @contents;
	push(@contents, <<EOF);
    <tr>
     <td>
      <p>The aus.* newsgroup administration is a volunteer effort to maintain
    and develop the aus.* USENET newsgroup hierarchy. We will achieve this by
    setting a clear policy for the growth of Australian newsgroups,
    managing the creation and deletion of newsgroups according to this
    policy, and providing online information to support the development
    of Australian newsgroups as a national resource.</p>

      <p>The aus.* administrator is currently
    Nick Andrew (<a href="http://www.nick-andrew.net">www.nick-andrew.net</a>),
    and operational staff and facilities are provided by
    <a href="http://www.tull.net/">Tullnet Pty Ltd</a>.

      <p>We wish to automate the administration task as much as possible.
    Before sending any questions by email make sure you have read the
    relevant FAQs and are aware of our current policy. This web site
    should cover most, if not all, queries you may have. If something
    seems important to you and it's not available here then please send
    some email.</p>

      <br>
     </td>
    </tr>
EOF
	return \@contents;
}

sub ausadminRoleRow {
	my @contents;
	push(@contents, <<EOF);
    <tr>
     <td>
      <ul>
       <li>Determine a good long-term structure for the aus.* hierarchy
       <li>Accept newsgroup proposals which fit the policy and structure
       <li>Final decision on newsgroup creation by voting
       <li>Slowly purge obsolete groups
       <li>Encourage news admins to respond to ausadmin newgroup and rmgroup messages
      </ul>
      <br>
     </td>
    </tr>
EOF
	return \@contents;
}

sub ausadminStructureRow {
	my @contents;
	push(@contents, <<EOF);
    <tr>
     <td>
      <p>
       In other words, what extensions to the structure does ausadmin consider
       good or bad?
      </p>

      <p>Encouraged:</p>
      <ul>
       <li>aus.books extended by genre, or purpose (e.g. reviews)
       <li>aus.cars extended by manufacturer (not model)
       <li>aus.net.access extended by access technology name (e.g. adsl)
       <li>aus.politics extended by major philosophy (e.g. socialism -- but no crossposting)
       <li>aus.sport extensions include competitive activities
       <li>aus.rec extended by recreational non-competitive activies
       <li>aus.tv extended by genre or technology
      </ul>

      <p>Discouraged:</p>
      <ul>
       <li>Forsale groups outside the aus.ads hierarchy
       <li>All binary groups are discouraged (post a URL instead)
       <li>Regional subgroups, e.g. aus.motorcycles.wa (see wa.* and other regional hierarchies)
       <li>aus.org subgroups
       <li>aus.tv subgroups for particular shows
      </ul>

      <p>In general, be aware if the topic you are proposing can be discussed
      from another perspective within an existing aus.* group, for example
      aus.books.sf may be discussed in aus.sf already.
      </p>
      <br>
     </td>
    </tr>
EOF
	return \@contents;
}

sub ausadminPolicyRow {
	my @contents;
	push(@contents, <<EOF);
    <tr>
     <td>
      <ul>
       <li>Newsgroup creation only (no newsgroup deletions yet)
       <li>Unmoderated newsgroup creation only
       <li>Proposals considered by ausadmin to be frivolous or intended to "work the system" will be rejected
       <li>No change of newsgroups from unmoderated to moderated (it caused a terrible storm last time)
       <li>2-level newsgroups (aus.X) accepted only for major categories (e.g. science, arts, sport, humanities -- most of which exist already)
       <li>3-level newsgroups (aus.X.Y) accepted only when parent exists (aus.X) or a sibling group already exists (aus.X.Z)
       <li>The effect of the above two rules is that if you want a new group e.g. <i>aus.language.strine</i> with no existing parent and no siblings, then you need to first work on getting <i>aus.language</i> created, and that group will have to make do for strine discussions as well as other language discussions. You would then wait 1-2 years before proposing <i>aus.language.strine</i>.
       <li>No change of charter yet, but if you wish to propose a charter for an existing group which does not already have a charter, email it in and ausadmin will consider accepting it directly as the new charter.
      </ul>
      <br>
     </td>
    </tr>
EOF
	return \@contents;
}

sub ausadminLinksRow {
	my @contents;
	push(@contents, <<EOF);
    <tr>
     <td>
      <a href="ftp://rtfm.mit.edu/pub/usenet-by-hierarchy/aus/">aus.* FAQs on rtfm.mit.edu</a><br>
      <a href="http://mirror.aarnet.edu.au/pub/rtfm/usenet-by-hierarchy/aus/">aus.* FAQs on mirror.aarnet.edu.au (local mirror of rtfm)</a><br>
      <a href="http://www.newsreaders.com/">www.newsreaders.com</a> (very comprehensive USENET resource)<br>
      <br>
     </td>
    </tr>
EOF
	return \@contents;
}

sub ausadminCreationProposalsRow {
	my @contents;
	push(@contents, <<EOF);
    <tr>
     <td>
      <p>
       Six Simple Steps to creation of a new newsgroup:
       <br>
       <ol>
        <li>Make sure you really need a new newsgroup, and not a mailing list or a website or an existing newsgroup</li>
	<li>Define the Topic and choose a group name which meets the ausadmin policy (above)</li>
	<li>Discuss your idea on aus.net.news</li>
	<li>Submit a formal proposal to ausadmin</li>
	<li>Participate in the Request For Discussion (RFD) process</li>
	<li>Ask ausadmin to put your proposal to the vote.</li>
       </ol>
     </td>
    </tr>

    <tr>
     <td>
      <p>
       Further detail on the process is in the
       <a href="/Faq/aus_faq">Group&nbsp;creation&nbsp;FAQ</a>.
      </p>
      <p>
       You will also need this template:
       <br>
       <a href="Faq/RFD-template.txt">Template for writing an RFD (Request For Discussion)</a></br>
      <br>
     </td>
    </tr>
EOF
	return \@contents;
}

1;
