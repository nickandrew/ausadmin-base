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

parse-rfd.pl [-d] newsgroup-name rfd-filename

=head1 DESCRIPTION

Parse the RFD file and write the following files in the
vote/$newsgroup subdirectory:

charter distribution ngline proposer rationale

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

die "No proposer" if (!defined $g->{proposer});
die "No distribution" if (!@{$g->{distribution}});


# Do basic sanity checks on all newsgroups in our RFD

foreach my $newsgroup (@newsgroups) {

	my $r = $g->{$newsgroup};

	die "$newsgroup: No newsgroups line" if (!defined $r->{ngline});
	die "$newsgroup: No rationale" if (!@{$r->{rationale}});
	die "$newsgroup: No charter" if (!@{$r->{charter}});
	if (@{$r->{modinfo}}) {
		die "$newsgroup: No moderator" if (!defined $r->{moderator});
	}
}

# Now output all the control file information ...

foreach my $newsgroup (@newsgroups) {

	my $r = $g->{$newsgroup};


	mkdir("$BaseDir/$newsgroup", 0755);

	open(O, ">$BaseDir/$newsgroup/proposer") or die "Unable to write proposer";
	print O $g->{proposer}, "\n";
	close(O);

	open(O, ">$BaseDir/$newsgroup/distribution") or die "Unable to write distribution";
	print O join("\n",@{$g->{distribution}}), "\n";
	close(O);

	open(CHARTER, ">$BaseDir/$newsgroup/charter") or die "Unable to write charter";
	print CHARTER join("\n",@{$r->{charter}}), "\n";
	close(CHARTER);

	open(RATIONALE, ">$BaseDir/$newsgroup/rationale") or die "Unable to write rationale";
	print RATIONALE join("\n",@{$r->{rationale}}), "\n";
	close(RATIONALE);

	open NGLINE,">$BaseDir/$newsgroup/ngline" or die "Unable to open ngline: $!";
	print NGLINE "$newsgroup\t$r->{ngline}\n";
	close NGLINE or die "Unable to close ngline: $!";

	if (exists $r->{modinfo}) {
		open(MODINFO, ">$BaseDir/$newsgroup/modinfo") or die "Unable to write modinfo";
		print MODINFO join("\n",@{$r->{modinfo}}), "\n";
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

	while ( <> ) {
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

		if (/^RATIONALE:\s*(.*)/i ) {
			$state = 'rationale';
			die "Rationale line missing group name" if (!defined $1);
			$groupname = $1;
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
			push(@{$g{$groupname}->{rationale}}, $_);
			next;
		}

		if ($state eq 'charter') {
			push(@{$g{$groupname}->{charter}}, $_);
			next;
		}

		if ($state eq 'modinfo') {
			if (/^Moderator:\s+(.+)/i) {
				$g{$groupname}->{moderator} = $1;
			}
			push(@{$g{$groupname}->{modinfo}}, $_);
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

		if ($state eq 'procedure') {
			# ignore
			next;
		}
	}

	return \%g;
}
