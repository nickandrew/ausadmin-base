#!/usr/bin/perl -w
#	@(#) $Header$

package View::MainPage;

use strict;
use warnings;

use VoteList qw();
use Include qw();

sub new {
	my $class = shift;
	my $self = { @_ };

	bless $self, $class;
	return $self;
}

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

# ---------------------------------------------------------------------------
# The contents of just inside the body
# ---------------------------------------------------------------------------

sub insideBody {
	my ($cookies, $filename) = @_;

	my @contents;

	push(@contents, <<EOF);
<table width="600" cellpadding="0" cellspacing="0" border="0">
 <tr>
EOF

	push(@contents, leftColumn($cookies));
	push(@contents, rightColumn($cookies, $filename));

	push(@contents, <<EOF);
 </tr>
</table>
EOF

	return \@contents;
}

# ---------------------------------------------------------------------------
# The left column (the narrow one)
# ---------------------------------------------------------------------------

sub leftColumn {
	my $cookies = shift;

	my @contents;

	push(@contents, <<EOF);
  <td class="lhs" bgcolor="#ffffe0" width="100" valign="top">
EOF

	push(@contents, loginBox($cookies));
	push(@contents, ausadminHeader($cookies));

	my $votelist = new VoteList(vote_dir => "$ENV{AUSADMIN_HOME}/vote");
	push(@contents, proposalList($votelist));
	push(@contents, runningVotesList($votelist));
	push(@contents, newsgroupList());

	push(@contents, <<EOF);
  </td>
EOF

	return \@contents;
}

# ---------------------------------------------------------------------------
# Return a 'username/password/register' box
# ---------------------------------------------------------------------------

sub loginBox {
	my $cookies = shift;

	my $uri_prefix = Ausadmin::config('uri_prefix');
	my $username = $cookies->getUserName();

	if ($username) {
		return qq{
<form method="POST">
<input type="hidden" name="action" value="logout" />
<table border="1" cellpadding="1" cellspacing="0">
<tr>
 <td>Logged in as $username</td>
</tr>

<tr>
 <td><input type="submit" value="Logout" /></td>
</tr>
</table>
</form>
};
	}

	# They are not logged in.

	return qq{
<form method="POST">
<input type="hidden" name="action" value="login">
<table border="1" cellpadding="1" cellspacing="0">
<tr>
 <td colspan="3">Please login or register</td>
</tr>

<tr>
 <td>Username</td>
 <td colspan="2"><input name="username" maxlength="16"></td>
</tr>

<tr>
 <td>Password</td>
 <td><input name="password" type="password" size="10" maxlength="16"></td>
 <td><input type="submit" value="Go"></td>
</tr>

<tr>
 <td colspan="3" align="center" >
  <a href="$uri_prefix/register.cgi">Register</a> /
  <a href="$uri_prefix/lostpass.cgi">Lost Password</a>
</tr>

</table>
</form>
};

};

# ---------------------------------------------------------------------------
# ??
# ---------------------------------------------------------------------------

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
		return '';
	}

	push(@contents, <<EOF);
<!-- start of proposals -->
<p>
<b>Proposals:</b><br />
EOF

	foreach my $v (@proposals) {
		my $p = $v->getName();
		my $s = "&nbsp;&nbsp;<a href=\"/proposal.cgi?proposal=$p\">$p</a><br />\n";
		push(@contents, $s);
	}

	push(@contents, <<EOF);
</p>
<!-- end of proposals -->
EOF
	return join('', @contents);
}

sub runningVotesList {
	my $votelist = shift;
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

sub newsgroupList {
	my @contents;

	# Return an array of newsgroup names
	my @newsgrouplist = Newsgroup::list_newsgroups(datadir => "$ENV{AUSADMIN_DATA}");

	if (!@newsgrouplist) {
		return undef;
	}

	push(@contents, <<EOF);
<p>
<b>Newsgroups:</b><br />
EOF

	foreach my $g (@newsgrouplist) {
		my $s = "&nbsp;&nbsp;<a href=\"groupinfo.cgi/$g/\">$g</a><br />\n";
		push(@contents, $s);
	}

	push(@contents, <<EOF);
</p>
EOF
	return join('', @contents);
}

sub rightColumn {
	my ($cookies, $filename) = @_;

	my @contents;
	push(@contents, <<EOF);
  <!-- Next column -->
  <td valign="top">
EOF
	push(@contents, ausadminHeading());
	push(@contents, ausadminContents($filename));

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
     <font face="sans-serif">$hier Newsgroup Administration</font>
    </h1>
   </center>
EOF
	return \@contents;
}

sub ausadminContents {
	my $filename = shift;

	my @contents;

	my $inc = new Include();
	push(@contents, $inc->resolveFile($filename));
	return \@contents;
}

sub ausadminSubHeadingRow {
	my $string = shift;

	my @contents;
	push(@contents, <<EOF);

    <tr bgcolor="#000000">
     <td>
      <font size="+1" color="#66cc66" face="sans-serif"><b>$string</b></font>
     </td>
    </tr>
EOF
	return \@contents;
}

# ---------------------------------------------------------------------------
# Callback function for the use of the template engine
# ---------------------------------------------------------------------------

sub viewFunction {
	my ($self, $include, $function_name, @args) = @_;

	if ($function_name eq 'loginBox') {
		my @contents;
		push(@contents, loginBox($self->{cookies}));
		return join('', @contents);
	}
	elsif ($function_name eq 'proposalList') {
		my @contents;
		my $votelist = new VoteList(vote_dir => "$ENV{AUSADMIN_HOME}/vote");
		push(@contents, proposalList($votelist));
		return join('', @contents);
	}
	elsif ($function_name eq 'runningVotesList') {
		my @contents;
		my $votelist = new VoteList(vote_dir => "$ENV{AUSADMIN_HOME}/vote");
		push(@contents, runningVotesList($votelist));
		return join('', @contents);
	}
	elsif ($function_name eq 'newsgroupList') {
		my @contents;
		push(@contents, newsgroupList());
		return join('', @contents);
	}
	elsif ($function_name eq 'contentFile') {
		my $string = $include->resolveFile($self->{content});
		if (!defined $string) {
			return "<b>No file $self->{content}</b>";
		}
		return $string;
	}

	return "<b>Unable to do function: $function_name</b>";
}

1;
