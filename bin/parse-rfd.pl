#!/usr/bin/perl
#	@(#) parse-rfd.pl: Read an RFD style proposal message, grab important info and save
#
# $Source$
# $Revision$
# $Date$
#
# Creates the control files for the newsgroup(s) referred to in an RFD
# and populates them with interesting things like the proposer name and
# the group rationale and charter.

=head1 NAME

parse-rfd.pl - Read an RFD style proposal file and split into its components

=head1 SYNOPSIS

parse-rfd.pl [B<-r>] [B<-d>] proposal-name < rfd-file

=head1 DESCRIPTION

Parse the proposal file and write one or more of the following files in the
vote/$proposal subdirectory:

change,
charter:$newsgroup,
distribution,
ngline:$newsgroup,
proposer,
rationale,

and optionally: modinfo

A B<proposal> and a B<newsgroup> are usually the same thing, unless the
proposal includes multiple newsgroups, in which case it should be named
differently.

=head1 OPTIONS

B<-d> turns on debugging mode; this is more verbose

B<-r> signals that this input file replaces an existing RFD (so the
directory used is assumed to exist already). If this flag is not
specified, the directory must not already exist, and will be created.

=cut


use Time::Local;
use IO::Handle;
use Getopt::Std;

use lib 'perllib';
use Newsgroup;

# Info Needed to run the script
my $BaseDir = "./vote";

my %opts;
getopts('rd', \%opts);

my $proposal_name = shift @ARGV || die "Usage: parse-rfd.pl proposal_name < proposal_file\n";

die "In wrong directory - no $BaseDir" if (!-d $BaseDir);

if (-d "$BaseDir/$proposal_name" && !$opts{'r'}) {
	die "$BaseDir/$proposal_name already exists, specify the -r option\n";
}
	
my $g = ReadRFD();

die "Unable to parse the RFD, sorry" unless %$g;

# Die if a change is not defined. This is very important!

if (!defined $g->{change}) {
	die "A CHANGE line is required for all proposals";
}

# All proposals need exactly one of these
die "No proposer" if (!defined $g->{proposer});
die "No distribution" if (!@{$g->{distribution}});
die "No rationale" if (!defined $g->{rationale});

my $change_type = $g->{change}->{'type'};

# Do basic sanity checks on all newsgroups in our RFD

# KLUDGE ... circular logic!

foreach my $change ($g->{change}) {

	my $change_type = $change->{'type'};
	my $change_newsgroup = $change->{'newsgroup'};

	if ($change_newsgroup eq '') {
		print STDERR "No newsgroup specified for this change!\n";
		next;
	}

	my $r = $g->{newsgroup}->{$change_newsgroup};

	if ($change_type =~ /^(newgroup|moderate|unmoderate)$/) {
		# Needs a newsgroups line
		die "$change_newsgroup: No newsgroups line" if (!defined $r->{ngline});
	}

	if ($change_type =~ /^(newgroup|moderate|unmoderate|charter)$/) {
		# Needs a charter paragraph
		die "$change_newsgroup: No charter" if (!defined $r->{charter});
	}

	# KLUDGE ...
	if (defined $r->{modinfo}) {
		die "$change_newsgroup: No moderator" if (!defined $r->{moderator});
	}

	# Now look for things which are not permitted
	if ($change_type =~ /^(rmgroup)$/) {
		die "$change_newsgroup: No charter permitted" if (defined $r->{charter});
		die "$change_newsgroup: No ngline permitted" if (defined $r->{ngline});
	}
}

my $directory = "$BaseDir/$proposal_name";

if (!$opts{'r'}) {
	if (!mkdir($directory, 0755)) {
		die "Unable to mkdir($directory,0755): $!\n";
	}
}

# Now output all the control file information ...

open(O, ">$directory/change") or die "Unable to open change for write: $!";
foreach my $k (sort (keys %{$g->{change}})) {
	print O $k, ": ", $g->{change}->{$k}, "\n";
}
close(O);

open(O, ">$directory/proposer") or die "Unable to open proposer for write: $!";
print O $g->{proposer}, "\n";
close(O);

open(O, ">$directory/distribution") or die "Unable to open distribution for write: $!";
print O join("\n",@{$g->{distribution}}), "\n";
close(O);

open(RATIONALE, ">$directory/rationale") or die "Unable to open rationale for write: $!";
print RATIONALE $g->{rationale};
close(RATIONALE);

# Now the newsgroup-specific information ...

foreach my $newsgroup (sort (keys %{$g->{newsgroup}})) {

	my $r = $g->{newsgroup}->{$newsgroup};

	if (defined $r->{charter}) {
		open(CHARTER, ">$directory/charter:$newsgroup") or die "Unable to open charter:$newsgroup for write: $!";
		print CHARTER $r->{charter};
		close(CHARTER);
	}

	if (defined $r->{ngline}) {
		open NGLINE,">$directory/ngline:$newsgroup" or die "Unable to open ngline:$newsgroup: $!";
		print NGLINE "$newsgroup\t$r->{ngline}\n";
		close NGLINE or die "Unable to close ngline: $!";
	}

	if (defined $r->{modinfo}) {
		open(MODINFO, ">$directory/modinfo:$newsgroup") or die "Unable to open modinfo:$newsgroup for write: $!";
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
			# This is the old style which doesn't support multi groups
			print STDERR "Old style Newsgroups line ignored!\n";
			next;
		}

		if (/^NGLINE:\s*([a-zA-Z0-9.-]+):\s*(.+)/i ) {
			$g{newsgroup}->{$1}->{ngline} = $2;
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

				# Charters now default to text format
				$c->{charter} = 'text';

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

				# Charters now default to HTML format
				$c->{charter} = 'html';

				$g{change} = $c;
				next;
			}

			if ($words[0] eq 'unmoderate') {
				die "unmoderate change type not handled yet";
				next;
			}

			# Change charter of an existing group
			if ($words[0] eq 'charter') {
				$c->{newsgroup} = $words[1];

				# Charters now default to HTML format
				$c->{charter} = 'html';

				next;
			}

			die "Unknown change type: $words[0]";
			next;
		}

		if (/^RATIONALE:/i ) {
			$state = 'rationale';
			next;
		}

		if (/^CHARTER:\s*(\S*)/i ) {
			$state = 'charter';
			die "Charter line missing group name" if (!defined $1);
			$groupname = $1;
			next;
		}

		if (/^MODERATOR INFO:\s*(\S*)/i ) {
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

		if (/^END DISTRIBUTION/i ) {
			undef $state;
			next;
		}

		if (/^END MODERATOR INFO/i ) {
			undef $state;
			next;
		}

		if ($state eq 'rationale') {
			$g{rationale} .= $_ . "\n";
			next;
		}

		if ($state eq 'charter') {
			$g{newsgroup}->{$groupname}->{charter} .= $_ . "\n";
			next;
		}

		if ($state eq 'modinfo') {
			if (/^Moderator:\s+(.+)/i) {
				$g{newsgroup}->{$groupname}->{moderator} = $1;
				next;
			}
			$g{newsgroup}->{$groupname}->{modinfo} .= $_ . "\n";
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

	}

	# Massage the data before returning ...
	foreach my $group (keys %{$g{newsgroup}}) {
		my $r = $g{newsgroup}->{$group};

		# Remove leading and trailing empty lines, trailing spaces
		cleanup_string($r, 'ngline');
		cleanup_string($r, 'charter');
		cleanup_string($r, 'moderator');
		cleanup_string($r, 'modinfo');
	}

	cleanup_string(\%g, 'proposer');
	cleanup_string(\%g, 'rationale');

	return \%g;
}

# cleanup_string() ... removes all trailing blanks from a multi-line
# string and eliminates empty lines at the start and the end.

sub cleanup_string {
	my $r = shift;
	my $key = shift;

	if (exists $r->{$key}) {
		# Remove trailing space and tab from each line
		$r->{$key} =~ s/[ \t]+\n/\n/g;

		# Remove blank lines at start
		$r->{$key} =~ s/^\n+//;

		$r->{$key} =~ s/\n\n+$/\n/;
#		$r->{$key} =~ s/\s+$//;
#		$r->{$key} =~ s/^\s+//;
		if ($r->{$key} eq '') {
			delete $r->{$key};
		}
	}
}
