#!/usr/bin/perl
#	@(#) parse-rfd.pl: Read an RFD message, grab important info and save
#
# $Source$
# $Revision$
# $Date$
#
# Creates the control files for the newsgroup(s) referred to in an RFD
# and populates them with interesting things like the proposer name and
# the group rationale and charter.

=head1 NAME

parse-rfd.pl - Read an RFD file and split into its components

=head1 SYNOPSIS

parse-rfd.pl [-d] newsgroup-name < rfd-file

=head1 DESCRIPTION

Parse the RFD file and write one or more of the following files in the
vote/$newsgroup subdirectory:

change,
charter,
distribution,
ngline,
proposer,
rationale,

and optionally: modinfo

=cut


use Time::Local;
use IO::Handle;
use Getopt::Std;

use lib 'bin';
use Newsgroup;

# Info Needed to run the script
my $BaseDir = "./vote";

my %opts;
getopts('d', \%opts);

die "In wrong directory - no $BaseDir" if (!-d $BaseDir);

my $g = ReadRFD();

die "Unable to parse the RFD, no newsgroups, sorry" unless %$g;

# Ignore special keys in the $g hashref, they are not newsgroup names.

my @newsgroups = grep { /^[a-z0-9-]+\.([a-z0-9.-]+)$/ } (sort (keys %$g));

# Setup defaults if CHANGE: line not supplied

if (!defined $g->{change}) {
	# Default change is to create a new unmoderated group
	$g->{change} = {
		'type' => 'newgroup',
		'newsgroup' => $newsgroups[0],		# KLUDGE
		'mod_status' => 'y'
	};
}

# All proposals need these
die "No proposer" if (!defined $g->{proposer});
die "No distribution" if (!@{$g->{distribution}});
die "No rationale" if (!defined $g->{rationale});

my $change_type = $g->{change}->{'type'};

# Do basic sanity checks on all newsgroups in our RFD

# KLUDGE ... circular logic!

@newsgroups = ($g->{change}->{newsgroup});

foreach my $newsgroup (@newsgroups) {

	my $r = $g->{$newsgroup};

	if ($change_type =~ /^(newgroup|moderate|unmoderate)$/) {
		# Needs a newsgroups line
		die "$newsgroup: No newsgroups line" if (!defined $r->{ngline});
	}

	if ($change_type =~ /^(newgroup|moderate|unmoderate|charter)$/) {
		# Needs a charter paragraph
		die "$newsgroup: No charter" if (!defined $r->{charter});
	}

	# KLUDGE ...
	if (defined $r->{modinfo}) {
		die "$newsgroup: No moderator" if (!defined $r->{moderator});
	}

	# Now look for things which are not permitted
	if ($change_type =~ /^(rmgroup)$/) {
		die "$newsgroup: No charter permitted" if (defined $r->{charter});
		die "$newsgroup: No ngline permitted" if (defined $r->{ngline});
	}
}

# Now output all the control file information ...

foreach my $newsgroup (@newsgroups) {

	my $r = $g->{$newsgroup};

	mkdir("$BaseDir/$newsgroup", 0755);

	open(O, ">$BaseDir/$newsgroup/change") or die "Unable to open change for write: $!";
	foreach my $k (sort (keys %{$g->{change}})) {
		print O $k, ": ", $g->{change}->{$k}, "\n";
	}
	close(O);

	open(O, ">$BaseDir/$newsgroup/proposer") or die "Unable to open proposer for write: $!";
	print O $g->{proposer}, "\n";
	close(O);

	open(O, ">$BaseDir/$newsgroup/distribution") or die "Unable to open distribution for write: $!";
	print O join("\n",@{$g->{distribution}}), "\n";
	close(O);

	open(RATIONALE, ">$BaseDir/$newsgroup/rationale") or die "Unable to open rationale for write: $!";
	print RATIONALE $g->{rationale};
	close(RATIONALE);

	if (defined $r->{charter}) {
		open(CHARTER, ">$BaseDir/$newsgroup/charter") or die "Unable to open charter for write: $!";
		print CHARTER $r->{charter};
		close(CHARTER);
	}

	if (defined $r->{ngline}) {
		open NGLINE,">$BaseDir/$newsgroup/ngline" or die "Unable to open ngline: $!";
		print NGLINE "$newsgroup\t$r->{ngline}\n";
		close NGLINE or die "Unable to close ngline: $!";
	}

	if (defined $r->{modinfo}) {
		open(MODINFO, ">$BaseDir/$newsgroup/modinfo") or die "Unable to open modinfo for write: $!";
		print MODINFO $r->{modinfo};
		close(MODINFO);
	}
}

# All done

exit(0);


# This sub grabs the required info from the RFD piped into the script.

sub ReadRFD {
	my @groups;
	my %g;

	my $old_state;
	my $state;
	my $groupname;

	while ( <STDIN> ) {
		chomp;

		if ($opts{'d'} && $old_state ne $state) {
			print STDERR "State: $old_state -> $state\n";
			$old_state = $state;
		}

		if ($opts{'d'}) {
			print STDERR "   $_\n";
		}

		if (/^Newsgroup(s?) line(s?):/i ) {
			$state = 'ngline';
			next;
		}

		# The change line defines what change is to be made if
		# this RFD then CFV passes.

		if (/^CHANGE:\s+(.+)/) {
			my @words = split(/\s+/, $1);
			my $c = { 'type' => $words[0] };
			if ($words[0] eq 'newgroup') {
				$c->{newsgroup} = $words[1];
				$c->{mod_status} = $words[2] || 'y';
				$c->{submission_email} = $words[3] if ($words[3]);
				$c->{request_email} = $words[4] if ($words[4]);
				$g{change} = $c;
				next;
			}
			if ($words[0] eq 'rmgroup') {
				$c->{newsgroup} = $words[1];
				$g{change} = $c;
				next;
			}
			if ($words[0] eq 'moderate') {
				$c->{newsgroup} = $words[1];
				$c->{mod_status} = 'm';
				$c->{submission_email} = $words[2];
				$c->{request_email} = $words[3];
				$g{change} = $c;
				next;
			}
			if ($words[0] eq 'unmoderate') {
				die "unmoderate change type not handled yet";
				next;
			}

			die "Unknown change type: $words[0]";
			next;
		}

		if (/^RATIONALE:\s*(.*)/i ) {
			$state = 'rationale';
			next;
		}

		if (/^CHARTER:\s*(.*)/i ) {
			$state = 'charter';
			die "Charter line missing group name" if (!defined $1);
			$groupname = $1;
			next;
		}

		if (/^MODERATOR INFO:\s*(.*)/i ) {
			$state = 'modinfo';
			die "Moderator Info line missing group name" if (!defined $1);
			$groupname = $1;
			next;
		}

		if (/^PROCEDURE:/i ) {
			$state = 'procedure';
			next;
		}

		if (/^DISTRIBUTION:/i ) {
			$state = 'distribution';
			next;
		}

		if (/^Proponent:/i ) {
			undef $state;
			# Ignore this line
			next;
		}

		if (/^PROPOSER:\s+(.+)/i ) {
			undef $state;
			die "Proposer line missing details" if (!defined $1);
			$g{proposer} = $1;
			next;
		}

		if (/^END RATIONALE/i ) {
			undef $state;
			next;
		}

		if (/^END CHARTER/i ) {
			undef $state;
			next;
		}

		if (/^END MODERATOR INFO/i ) {
			undef $state;
			next;
		}

		if ($state eq 'ngline') {
			if (/^([^\s]+)\s+(.*)/i) {
				$g{$1}->{ngline} = $2;
			}
			next;
		}

		if ($state eq 'rationale') {
			$g{rationale} .= $_ . "\n";
			next;
		}

		if ($state eq 'charter') {
			$g{$groupname}->{charter} .= $_ . "\n";
			next;
		}

		if ($state eq 'modinfo') {
			if (/^Moderator:\s+(.+)/i) {
				$g{$groupname}->{moderator} = $1;
				# next ?
			}
			$g{$groupname}->{modinfo} .= $_ . "\n";
			next;
		}

		if ($state eq 'procedure') {
			# ignore
			next;
		}

		if ($state eq 'distribution') {
			if (/^\s*(\S+)\s*$/) {
				if (Newsgroup::validate($1)) {
					push(@{$g{distribution}}, $1);
				}
			}
			next;
		}

#		if ($state eq 'procedure') {
#			# ignore
#			next;
#		}

	}

	# Massage the data before returning ...
	foreach my $group (keys %g) {
		next if ($group eq 'distribution');
		my $r = $g{$group};

		# Remove leading and trailing empty lines, trailing spaces
		cleanup_string($r, 'ngline');
		cleanup_string($r, 'proposer');
		cleanup_string($r, 'charter');
		cleanup_string($r, 'moderator');
		cleanup_string($r, 'modinfo');
	}

	cleanup_string(\%g, 'rationale');

	return \%g;
}

# cleanup_string() ... removes all trailing blanks from a multi-line
# string and eliminates empty lines at the start and the end.

sub cleanup_string {
	my $r = shift;
	my $key = shift;

	if (exists $r->{$key}) {
		$r->{$key} =~ s/ +\n/\n/g;
		$r->{$key} =~ s/^\n+//;
		$r->{$key} =~ s/\n\n+$/\n/;
		if ($r->{$key} eq '') {
			delete $r->{$key};
		}
	}
}
