#!/usr/bin/perl -w
#	@(#) $Header$
#
#	Read a consolidated server_report.xml and write a text report

use XML::Simple qw();
use Date::Format qw(time2str);

my $path = "$ENV{AUSADMIN_HOME}/server_reports.xml";
my $db = XML::Simple::XMLin($path, forcearray => 1);

# Score each server
foreach my $server (keys %{$db->{server}}) {
	my $r = $db->{server}->{$server};
	my $total_groups = $r->{total_groups};
	my $score = ($total_groups - $r->{missing} - $r->{bogus} * 0.5);
	my $tpct = int(1000 * $score / $total_groups);
	$r->{name} = $server;
	$r->{score} = $score;
	$r->{tpct} = $tpct;
}

# Now report on each server

print <<EOF;
Ausadmin (with the help of volunteers) monitors the list of groups
on several newsservers in order to identify differences compared
to the canonical list maintained by ausadmin.

Each server is checked for existing groups (shown as 'Ok' on
the following report), groups which should be added ('Missing'),
and groups which were added but are not part of the canonical list
(shown as 'Bogus'). Each server is then assigned a score from 0 to
100 which represents how consistently the server has followed the
canonical newsgroup list.

The servers for which Ausadmin has received information are listed
below, ranked by decreasing score.

EOF

print " #  Server Name                           Ok  Missing  Bogus  Score\n";
print "--  ---------------------------------    ---  -------  -----  -----\n";

my $rank = 1;
my $position = 1;
my $pct = '';

foreach my $r (sort { $b->{tpct} <=> $a->{tpct} } (values %{$db->{server}})) {
	if ($pct eq '') {
		$pct = $r->{tpct};
	} elsif ($pct > $r->{tpct}) {
		$rank = $position;
		$pct = $r->{tpct};
	}

	# rank servername      ok missing  bogus    pct
	printf "%2d  %-35.35s  %3d   %3d     %3d    %5.1f\n",
		$rank,
		$r->{name},
		$r->{ok},
		$r->{missing},
		$r->{bogus} || 0,
		$r->{tpct}/10;
	$position ++;
}

print <<EOF;
Now here are the details of all differences for each newsserver
which is being monitored.

EOF

# Now report on each newsserver by name

foreach my $r (sort { $a->{name} cmp $b->{name} } (values %{$db->{server}})) {
	next if (!exists $r->{notice});

	my $str = sprintf("Report for %s", $r->{name});

	print "\n$str\n";
	print '-' x length($str), "\n\n";

	printf "  Last checked: %s\n\n",
		time2str("%A, %d %B %Y", $r->{last_report});

	foreach my $group (sort (keys %{$r->{notice}})) {
		my $r2 = $r->{notice}->{$group};

		printf "  %-35.35s %s\n",
			$group,
			$r2->{msg};
	}

}

exit(0);

