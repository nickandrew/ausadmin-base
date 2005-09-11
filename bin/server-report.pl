#!/usr/bin/perl -w
#	@(#) $Header$
#
#	Read a consolidated server_report.xml and write a text report

use strict;

use XML::Simple qw();
use Date::Format qw(time2str);

my $min_age = time() - 86400 * 30;		# Require fresh data
my $path = "$ENV{AUSADMIN_HOME}/server_reports.xml";
my $db = XML::Simple::XMLin($path, forcearray => 1);

# Score each server
foreach my $server (keys %{$db->{server}}) {
	my $r = $db->{server}->{$server};
	my $total_groups = $r->{total_groups};
	my $score = ($total_groups - $r->{missing} * 3 - $r->{bogus} * 0.5);
	$score = 0 if ($score < 0);
	my $tpct = $total_groups ? int(1000 * $score / $total_groups) : 0;
	$r->{name} = $server;
	$r->{score} = $score;
	$r->{tpct} = $tpct;
}

# Now report on each server
my $today = time2str('%Y-%m-%d', time());

print <<EOF;
From: ausadmin\@aus.news-admin.org (Ausadmin)
Subject: Newsserver analysis report ($today)
Newsgroups: aus.net.news,aus.computers.linux

Ausadmin with the help of volunteers monitors the list of groups
on several newsservers in order to identify differences compared
to the canonical list maintained by ausadmin.

Each server is checked for existing groups (shown as 'Ok' on
the following report), groups which should be added ('Missing'),
and groups which were added but are not part of the canonical list
(shown as 'Bogus'). Each server is then assigned a score from 0 to
100 which represents how consistently the server has followed the
canonical newsgroup list.

See the bottom of this message if you would like to help out by
reporting on your ISP's newsserver. You can also help by emailing
the list of differences to your support group, and refer them to
the ausadmin website, http://aus.news-admin.org/ for details on
setting up automatic update.

-------------------------------------------------------------------------

The servers for which Ausadmin has received information are listed
below, ranked by decreasing score.

EOF

print " #  Server Name                           Ok  Missing  Bogus  Score\n";
print "--  ---------------------------------    ---  -------  -----  -----\n";

my $rank = 1;
my $position = 1;
my $pct = '';

foreach my $r (sort { $b->{tpct} <=> $a->{tpct} } (values %{$db->{server}})) {
	next if ($r->{last_report} < $min_age);
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

my $ignored;
foreach my $r (sort { $a->{name} cmp $b->{name} } (values %{$db->{server}})) {
	next if ($r->{last_report} >= $min_age);

	$ignored .= sprintf(
		"  %-25s - last checked %s\n",
		$r->{name},
		time2str("%A, %d %B %Y", $r->{last_report})
	);
}

if ($ignored) {
	print <<EOF;

Some servers are not included in this list because we have not received
a recent report for them:

$ignored
EOF
}


print <<EOF;

Now here are the details of all differences for each newsserver
which is being monitored.
EOF

# Now report on each newsserver by name

foreach my $r (sort { $a->{name} cmp $b->{name} } (values %{$db->{server}})) {
	next if ($r->{last_report} < $min_age);
	next if (!exists $r->{notice});
	next if ($r->{score} <= 0);

	my $str = sprintf("Report for %s", $r->{name});

	print "\n\n$str\n";
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

print <<EOF;

-------------------------------------------------------------------------

If you can assist in this effort to keep all the Australian
newsservers up-to-date and you are a *nix user, please do this
test first:

	perl -MNet::NNTP -MLWP::UserAgent -e ''

If the perl command returned with no output, then your *nix
box has all the necessary libraries installed to run the group
list client. Please download:

	http://aus.news-admin.org/download/nntp-group-list.pl

Edit the script, changing the hardcoded values at the start:

  news_server from 'news.example.com' to 'your.local.news.host'
  my_email    from 'you\@example.com'  to 'your.real.email\@your.domain'

chmod the script to mode 755, then add it to your crontab, on this
schedule:

0 4 * * 0	nntp-group-list.pl

Then cron will run the script at 4am local time every Sunday. The
script will connect to the ausadmin website, download the list of
interesting hierarchies, then connect to your local newsserver
and download the names and descriptions of all newsgroups in those
hierarchies. Finally, the script will email the results to
ausadmin\@aus.news-admin.org. Thank you!

Nick Andrew
<ausadmin\@aus.news-admin.org>
EOF

exit(0);

