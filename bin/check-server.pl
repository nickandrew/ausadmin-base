#!/usr/bin/perl
#	@(#) $Header$
#
#	Read an XML file which is a server report, and compare that
#	against the canonical newsgroup list
#
# Usage: check-server.pl < filename.xml

use XML::Simple qw();
use Data::Dumper qw(Dumper);

my $xml = join('', <STDIN>);

my $svr = XML::Simple::XMLin($xml);
my $hierarchies = { };

print "Report for ", $svr->{news_server}, "\n";

if (ref $svr->{hier}) {
	foreach my $hier (sort (keys %{$svr->{hier}})) {
		my $hr = read_hierarchy($hier);
		if (!defined $hr) {
			next;
		}

		check_existing_groups($hier, $svr->{hier}->{$hier}, $hr);
		check_bogus_groups($hier, $svr->{hier}->{$hier}, $hr);
	}

	# check it
}

exit(0);

sub check_existing_groups {
	my($hier, $sh_ref, $hr) = @_;

	if (!ref $sh_ref->{group}) {
		print "No groups in hierarchy $hier\n";
		return;
	}

	my $ghr = $sh_ref->{group};

	if (exists $ghr->{name}) {
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
		if (!exists $ghr->{$group}) {
			print "  Group $group needs to be created\n";
		}
	}
}

# ---------------------------------------------------------------------------
# Look for groups on this server which are not in the canonical list
# ---------------------------------------------------------------------------

sub check_bogus_groups {
	my($hier, $sh_ref, $hr) = @_;

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
			print "  Group $group is bogus\n";
		}

		return;
	}

	foreach my $group (sort (keys %$ghr)) {
		if (!exists $hr->{$group}) {
			print "  Group $group is bogus\n";
		}
	}
}

sub read_hierarchy {
	my $hier = shift;

	return $hierarchies->{$hier} if (exists $hierarchies->{$hier});

	if ($hier !~ /^(.*)\.\*$/) {
		die "Invalid hierarchy name: $hier";
	}

	my $dirname = "$ENV{AUSADMIN_HOME}/$1.data";

	if (! -d $dirname) {
		warn "Not a managed hierarchy: $hier ($dirname)\n";
		return undef;
	}

	print "Reading $hier\n";

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

