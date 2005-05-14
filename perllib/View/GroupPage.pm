#!/usr/bin/perl
#	@(#) $Header$

package View::GroupPage;

use strict;

use View::MainPage qw();
use Newsgroup qw();

sub insideBody {
	my $cookies = shift;
	my $ng = shift;

	my @contents;

	push(@contents, <<EOF);
  <table border="1" bgcolor="#ffffe0" cellspacing="0" cellpadding="3" width="98%">
   <tr>
EOF

	push(@contents, leftColumn($cookies, $ng));
	push(@contents, rightColumn($cookies, $ng));

	push(@contents, <<EOF);
   </tr>
  </table>
EOF

	return \@contents;
}

sub leftColumn {
	my $cookies = shift;
	my $ng = shift;

	my @contents;

	push(@contents, <<EOF);
    <td class="lhs" width="080" valign="top">
EOF

	push(@contents, View::MainPage::loginBox($cookies));
	push(@contents, View::MainPage::ausadminHeader());

	my $votelist = new VoteList(vote_dir => "$ENV{AUSADMIN_HOME}/vote");
	push(@contents, View::MainPage::proposalList($votelist));
	push(@contents, View::MainPage::runningVotesList($votelist));
	push(@contents, relatedVotesList($ng));

	push(@contents, <<EOF);
    </td>
EOF

	return \@contents;
}

sub relatedVotesList {
	my $ng = shift;

	my @contents;

	my $parent = $ng;
	$parent =~ s/\.[^.]+$//;

	my @newsgroup_list = Newsgroup::list_newsgroups( datadir => "$ENV{AUSADMIN_DATA}" );
	my @siblings;

	foreach my $fn (sort @newsgroup_list) {
		if ($fn =~ /^$parent/) {
			push(@siblings, $fn);
		}
	}

	return if (!@siblings);

	my $script_name = $ENV{SCRIPT_NAME};

	# FIXME
	push(@contents, <<EOF);
<b>See Also:</b><br />
EOF

	foreach my $n (@siblings) {
		push(@contents, "&nbsp;&nbsp;<a href=\"$script_name/$n/\">$n</a><br />\n");
	}

	return \@contents;
}

sub rightColumn {
	my $cookies = shift;
	my $ng = shift;

	my @contents;

	if (!defined $ng) {
		push(@contents, "Uh, no group name was specified.");
		return \@contents;
	}

	my $ngroup = new Newsgroup(name => $ng, datadir => "$ENV{AUSADMIN_DATA}");

	if (!defined $ngroup) {
		push(@contents, "Uh, cannot initialise $ng");
		return \@contents;
	}

	my $ngline = $ngroup->get_attr('ngline');
	my $charter = $ngroup->get_attr('charter');

	if (! $charter) {
		$charter = "No charter is available for the group $ng, sorry!";
	}

	push(@contents, <<EOF);
    <td valign="top">
     <center><h1>$ng</h1></center>
     <hr />
     <center><h2>$ngline</h2></center>
     <hr />
     <h3>Charter of $ng</h3>
      <blockquote>
      <pre>
$charter
      </pre>
      </blockquote>
     <h3>Activity graph of $ng (articles posted per day)</h3>
     <center>
      <img src="/article_rate_png.cgi?newsgroup=$ng" alt="Article posting rate graph for $ng" />
     </center>
     <p>The above graph is a moving average of the number of articles
     posted into $ng per day.
     The top of the green area counts the number
     of articles posted in the last 24 hours, whereas the blue line counts
     the number of articles posted in the last 2 hours, times 12.</p>
     <h4>Weekly activity graph</h4>
     <center>
      <img src="/article_rate_png.cgi?newsgroup=$ng&amp;type=week" alt="Last 7 days article posting rates for $ng" />
     </center>
     <h4>Monthly activity graph</h4>
     <center>
      <img src="/article_rate_png.cgi?newsgroup=$ng&amp;type=month" alt="Last 4 weeks article posting rates for $ng" />
     </center>
    </td>


EOF

	return \@contents;
}

1;
