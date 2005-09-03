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

sub proposalList {
	my $self = shift;
	my $votelist = shift;
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

sub proposalContents {
	my $self = shift;

	my $vote = $self->{vote};

	my $rfd_text = $vote->read_file("rfd");

	return qq{<pre>@$rfd_text</pre>};
}

# ---------------------------------------------------------------------------
# News items
# ---------------------------------------------------------------------------

sub news {
	my $self = shift;

	return "<b>No news today</b>\n";
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
		push(@contents, $self->proposalList($votelist));
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
		push(@contents, $self->newsgroupList());
		return join('', @contents);
	}
	elsif ($function_name eq 'contentFile') {
		my $string = $include->resolveFile($self->{content});
		if (!defined $string) {
			return "<b>No file $self->{content}</b>";
		}
		return $string;
	}
	elsif ($function_name eq 'proposalContents') {
		my $string = $self->proposalContents();
		return $string;
	}
	elsif ($function_name eq 'news') {
		my $string = $self->news();
		return $string;
	}

	return "<b>Unable to do function: $function_name</b>";
}

1;
