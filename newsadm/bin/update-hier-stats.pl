#!/usr/bin/perl
#	@(#) update-hier-stats.pl: Keep a count on number of messages posted
#	into each hierarchy
#
#  Usage: update-hier-stats.pl newsgroup_file > hierarchy_stats

use Net::NNTP;

my $newsgroup_file = shift @ARGV;

my $newsserver = $ENV{NNTPSERVER} || 'news';

my $s = new Net::NNTP($newsserver, reader => 1);
if (!defined $s) {
	die "Unable to connect to $newsserver, sorry!\n";
}

my $ng_hr = { };

if (-f $newsgroup_file) {
	if (!open(N, "<$newsgroup_file")) {
		die "Unable to open $newsgroup_file for read: $!";
	}

	while (<N>) {
		chomp;
		my($group, $start_ts, $start, $last_ts, $last) = split(/\s+/);

		$ng_hr->{$group} = {
			'last' => $last,
			'last_ts' => $last_ts,
			'start' => $start,
			'start_ts' => $start_ts,
		};
	}
}

# Now update the last article in each newsgroup
# Ok, download a list of newsgroups and max art numbers

# This will take a long time
my $now = time();

my $hr = $s->list();
if (!defined $hr) {
	die "Unable to get updated active file!\n";
}

if (!open(N, ">$newsgroup_file")) {
	die "Unable to open $newsgroup_file for write: $!";
}

foreach my $group (sort (keys %$hr)) {
	my($last,$first,$flags) = @{$hr->{$group}};
	my $start;
	my $start_ts;

	if (!exists $ng_hr->{$group}) {
		# Set initial conditions for a new newsgroup
		$ng_hr->{$group} = {
			'start' => $last.
			'start_ts' => $now,
		};

		$start = $last;
		$start_ts = $now;
	} else {
		$start = $ng_hr->{$group}->{'start'};
		$start_ts = $ng_hr->{$group}->{'start_ts'};
	}

	$ng_hr->{$group}->{'last'} = $last;
	$ng_hr->{$group}->{'last_ts'} = $now;

	print N "$group $start_ts $start $now $last\n";
}

close(N);

# Now calculate top hierarchies
#

my $hiers = { };
my $active_count = 0;

foreach my $group (keys %$ng_hr) {
	my $hier = $group;
	my $r = $ng_hr->{$group};

	$hier =~ s/\..*//;

	if ($r->{'last'} > $r->{'start'}) {
		my $diff = $r->{'last'} - $r->{'start'};

		if (!exists $hiers->{$hier}) {
			$active_count++;
		}

		$hiers->{$hier} += $diff;
	}
}

if ($active_count > 10) {
	foreach my $hier (sort (keys %$hiers)) {
		printf "%-20s %10d\n", $hier, $hiers->{$hier};
	}
}

exit(0);
