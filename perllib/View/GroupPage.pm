#!/usr/bin/perl
#	@(#) $Header$

package View::GroupPage;

use strict;

use View::MainPage qw();
use Newsgroup qw();

sub insideBody {
	my $ng = shift;

	my @contents;

	push(@contents, <<EOF);
  <table border="1" bgcolor="#ffffe0" cellspacing="0" cellpadding="3" width="98%">
   <tr>
EOF

	push(@contents, leftColumn($ng));
	push(@contents, rightColumn($ng));

	push(@contents, <<EOF);
   </tr>
  </table>
EOF

	return \@contents;
}

sub leftColumn {
	my $ng = shift;

	my @contents;

	push(@contents, <<EOF);
    <td width="080" valign="top">
     <font size=-1>
EOF

	push(@contents, View::MainPage::ausadminHeader());

	my $votelist = new VoteList(vote_dir => "$ENV{AUSADMIN_HOME}/vote");
	push(@contents, View::MainPage::proposalList($votelist));
	push(@contents, View::MainPage::runningVotesList($votelist));
	push(@contents, relatedVotesList($ng));

	push(@contents, <<EOF);
     </font>
    </td>
EOF

	return \@contents;
}

sub relatedVotesList {
	my $ng = shift;

	my @contents;

	my $parent = $ng;
	$parent =~ s/\.[^.]+$//;

	my @newsgroup_list = Newsgroup::list_newsgroups( datadir => "$ENV{AUSADMIN_DATA}/Newsgroups" );
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
	my $ng = shift;

	my @contents;

	if (!defined $ng) {
		push(@contents, "Uh, no group name");
		foreach (keys %ENV) {
			push(@contents, "<br />$_ ... $ENV{$_}");
		}
		return \@contents;
	}

	my $ngroup = new Newsgroup(name => $ng, datadir => "$ENV{AUSADMIN_DATA}/Newsgroups");

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
     <hr>
     <center><h2>$ngline</h2></center>
     <hr>
     <h3>Charter of $ng</h3>
      <blockquote>
      <pre>
$charter
      </pre>
      </blockquote>
     <h3>Activity graph of $ng (articles posted per hour)</h3>
     <center>
      <img src="/article_rate_png.php?newsgroup=$ng" alt="Article posting rate graph for $ng">
     </center>

EOF

	return \@contents;
}

1;
