#!/usr/bin/perl
#	mrtg-newsgroup-arrival.pl - Return avg articles rcvd over an interval
#	@(#) $Header$

use Getopt::Std qw(getopts);

use vars qw($opt_f $opt_i);

getopts('f:i:');

$opt_f ||= '/home/ausadmin/tmp/mrtg-newsgroups-arrival.log';
$opt_i ||= 7200;
my $age = 1 * 86400;
my $age_factor =  86400 / $age;
my $recent_factor = 86400 / $opt_i;

my $now = time();

if (!-f $opt_f) {
	exit(2);
}

if (!open(G, "</etc/hostname")) {
	exit(3);
}

my $hostname = <G>;
chomp($hostname);
close(G);

open(G, "</proc/uptime");
my $l2;
chop($l2 = <G>);
close(G);

my($up1, $up2) = split(/\s+/, $l2);

my $updays = int($up1 / 86400);
my $uphours = ($up1 - $updays * 86400) / 3600;

my $uptime = sprintf "%d day(s) and %d hour(s)", $updays, $uphours;

my $then = $now - $opt_i;
my $really_old = $now - $age;

my %group_tally;

if (open(F, "<$opt_f")) {

	while (<F>) {
		chomp;
		my @w = split;

		if ($w[0] >= $then) {
			$group_tally{$w[1]}->{immed} += $w[2];
		}

		if ($w[0] >= $really_old) {
			$group_tally{$w[1]}->{aged} += $w[2];
		}
	}

	close(F);

	foreach my $newsgroup (sort (keys %group_tally)) {
		my $count = $group_tally{$newsgroup}->{immed} * $recent_factor;
		my $average = int($group_tally{$newsgroup}->{aged} * $age_factor);
		print "news-arrival:$newsgroup\n";
		print $average, "\n";
		print $count, "\n";
		print $uptime, "\n";
		print $hostname, "\n";
	}
}

exit(0);

