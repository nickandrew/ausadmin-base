#!/usr/bin/perl
#	@(#) $Header$

package View::GroupPage;

use strict;

use View::MainPage qw();
use Newsgroup qw();
use Include qw();

sub new {
	my $class = shift;
	my $self = { @_ };

	bless $self, $class;
	return $self;
}

# ---------------------------------------------------------------------------
# Callback function for the use of the template engine
# ---------------------------------------------------------------------------

sub viewFunction {
	my ($self, $include, $function_name, @args) = @_;

	if ($function_name eq 'contentFile') {
		my $string = $self->newsgroupHTML();
		return $string;
	}

	return "<b>Unable to do function: $function_name</b>";
}

sub newsgroupHTML {
	my $self = shift;
	my $ng = $self->{newsgroup};

	if (!defined $ng) {
		return "Uh, no group name was specified.";
	}

	my $ngroup = new Newsgroup(name => $ng, datadir => "$ENV{AUSADMIN_DATA}");

	if (!defined $ngroup) {
		return "Uh, cannot initialise $ng";
	}

	my $ngline = $ngroup->get_attr('ngline');
	my $charter = $ngroup->get_attr('charter');

	if (! $charter) {
		$charter = "No charter is available for the group $ng, sorry!";
	}

	my $s = '';

	$s .= <<EOF;
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
<p>
The above graph is a moving average of the number of articles
posted into $ng per day.
The top of the green area counts the number
of articles posted in the last 24 hours, whereas the blue line counts
the number of articles posted in the last 2 hours, times 12.
</p>

<h4>Weekly activity graph</h4>
<center>
   <img src="/article_rate_png.cgi?newsgroup=$ng&amp;type=week" alt="Last 7 days article posting rates for $ng" />
</center>

<h4>Monthly activity graph</h4>
<center>
   <img src="/article_rate_png.cgi?newsgroup=$ng&amp;type=month" alt="Last 4 weeks article posting rates for $ng" />
</center>


EOF

	return $s;
}

1;
