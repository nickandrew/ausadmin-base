#!/usr/bin/perl
#	@(#) $Header$
#
#	Read an XML file which is a server report, and compare that
#	against the canonical newsgroup list
#
# Usage: check-server.pl < filename.xml

use Getopt::Std qw(getopts);
use XML::Simple qw();
use Date::Format qw(time2str);
use Data::Dumper qw(Dumper);
use Fcntl qw(:flock);

use vars qw($opt_d);

getopts('d');

my $xml = join('', <STDIN>);

my $svr = XML::Simple::XMLin($xml, forcearray => 1);
if (! %$svr) {
	die "Reading - no data\n";
}

my $hierarchies = { };

my $lock_file = "$ENV{AUSADMIN_HOME}/check-server";
open(LOCK, ">$lock_file") || die "Unable to open $lock_file for write: $!";
flock(LOCK, LOCK_EX());

# Read our database of prior server reports
my $db_path = "$ENV{AUSADMIN_HOME}/server_reports.xml";
my $db = { };
if (-f $db_path) {
	$db = XML::Simple::XMLin($db_path, forcearray => 1);
}

# print Dumper($db);

process_server_report($svr);

# print "Result after modifications:\n";
# print Dumper($db);

my $str = XML::Simple::XMLout($db);
if (open(XMLOUT, ">$db_path")) {
	print XMLOUT $str;
	close(XMLOUT);
}


exit(0);

sub process_server_report {
	my $svr = shift;

	my $news_server = $svr->{news_server};

	printf "Report for %s by %s on %s\n",
		$news_server,
		$svr->{my_email},
		time2str('%Y-%m-%d %H:%M', $svr->{now});

	my $db_svr = $db->{server}->{$news_server};
	if ($db_svr) {
		if ($db_svr->{last_report} >= $svr->{now}) {
			my $last_report = $db_svr->{last_report};
			my $last_email = $db_svr->{last_email};

			printf " Ignoring, most recent report was %s by %s\n",
				time2str('%Y-%m-%d %H:%M', $last_report),
				$last_email;
			return;
		} else {
			printf " Update report from %s\n",
				$svr->{my_email};
		}
	} else {
		printf " New report from %s\n", $svr->{my_email};
	}

	if (!ref $svr->{hier}) {
		print " Error - no hierarchies\n";
		return;
	}

	# Now check it hierarchy by hierarchy

	my $result = $db->{server}->{$news_server} = {
		bogus => 0,
		missing => 0,
		total_groups => 0,
		ok => 0,
	};

	foreach my $hier (sort (keys %{$svr->{hier}})) {
		my $svr_hier = $svr->{hier}->{$hier};
		my $hr = read_hierarchy($hier);
		if (!defined $hr) {
			next;
		}

		check_existing_groups($hier, $svr_hier, $hr, $result);
		check_bogus_groups($hier, $svr_hier, $hr, $result);
	}

	$result->{last_report} = $svr->{now};
	$result->{last_email} = $svr->{my_email};
	$result->{last_revision} = $svr->{vers};
}

sub check_existing_groups {
	my($hier, $sh_ref, $hr, $result) = @_;

	if (!ref $sh_ref->{group}) {
		$result->{notice}->{$hier} = { msg => "No groups in hierarchy" };
		print " No groups in hierarchy $hier\n" if ($opt_d);
		return;
	}

	my $ghr = $sh_ref->{group};

	# This code should be obsolete with XML::Simple forcearray
	if (0 && exists $ghr->{name}) {
		# Turn it into a hashref like we would see with multi groups
		my $r = {
			description => $ghr->{description},
			flags => $ghr->{flags}
		};

		my $group = $ghr->{name};

		$ghr->{$group} = $r;
		delete $ghr->{name};
		delete $ghr->{description};
		delete $ghr->{flags};
	}

	foreach my $group (sort (keys %$hr)) {
		# $result->{hier}->{$hier}->{total_groups} ++;
		$result->{total_groups} ++;
		if (!exists $ghr->{$group}) {
			print "  Group $group needs to be created\n" if ($opt_d);
			$result->{missing} ++;
			$result->{notice}->{$group} = { msg => sprintf("Group should be created: %s", $hr->{$group}->{description}) };
		} else {
			$result->{ok} ++;
		}
	}
}

# ---------------------------------------------------------------------------
# Look for groups on this server which are not in the canonical list
# ---------------------------------------------------------------------------

sub check_bogus_groups {
	my($hier, $sh_ref, $hr, $result) = @_;

	# Ignore groups shown here which are not in the hierarchy
	my $hier_regex = $hier;
	$hier_regex =~ s/\./\\./g;
	$hier_regex =~ s/\*/.*/g;


	if (!ref $sh_ref->{group}) {
		return;
	}

	my $ghr = $sh_ref->{group};
	if (exists $ghr->{name}) {
		# It is a single group
		my $group = $ghr->{name};
		if (!exists $hr->{$group}) {
			print "  Group $group is bogus\n" if ($opt_d);
			$result->{bogus} ++;
			$result->{notice}->{$group} = { msg => "Group should be deleted" };
		}

		return;
	}

	foreach my $group (sort (keys %$ghr)) {
		if ($group !~ /^$hier_regex/) {
			print " Group $group is not part of $hier\n" if ($opt_d);
			next;
		}

		if (!exists $hr->{$group}) {
			print "  Group $group is bogus\n" if ($opt_d);
			$result->{bogus} ++;
			$result->{notice}->{$group} = { msg => "Group should be deleted" };
		}
	}
}

sub read_hierarchy {
	my $hier = shift;

	return $hierarchies->{$hier} if (exists $hierarchies->{$hier});

	if ($hier !~ /^(.*)\.\*$/) {
		die "Invalid hierarchy name: $hier";
	}
	my $shier = $1;

	my $dirname = Newsgroup::datadir($shier);

	if (! -d $dirname) {
		warn "Not a managed hierarchy: $hier ($dirname)\n";
		return undef;
	}

	print "Reading $hier\n" if ($opt_d);

	open(F, "<$dirname/grouplist") || ( print "No grouplist for $hier\n", return undef ) ;

	my $groups = { };

	while (<F>) {
		chomp;
		if (/^(\S+)\s*(.*)/) {
			$groups->{$1} = { name => $1, description => $2 };
		}
	}

	close(F);

	$hierarchies->{$hier} = $groups;

	return $groups;
}
