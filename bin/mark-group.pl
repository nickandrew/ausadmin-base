#!/usr/bin/perl
#	@(#) mark-group.pl - Mark some messages as being multi-votes

=head1 NAME

mark-group.pl - Mark some messages as being multi-votes

=head1 SYNOPSIS

 mark-group.pl [-n] vote-name filename ...

=head1 DESCRIPTION

Edit the B<tally.dat> file for the specified vote B<vote-name>
and mark the filenames given as suspected to originate from the
same person.

The B<-n> flag unmarks each message, i.e. returns it to NEW status.

This program will not change the status of any of the messages if any
of the following conditions occur:

 - No filenames are supplied
 - A supplied filename does not exist
 - A supplied filename is not in the vote's B<tally.dat> file
 - Any of the message status is not 'NEW' (*note)

(*note ... if the B<-n> flag is supplied, all message status must be
not NEW and must be the same string)

=cut

use Getopt::Std;
use Vote;
use Ausadmin;

use vars qw/$opt_n/;

getopts('n');

my $vote_name = shift @ARGV;
my %filenames;
my $exists = 1;
my $now = time();
my $multi_group;

# Leave multi_group blank if $opt_n
if (!$opt_n) {
	$multi_group = "MULTI-$now";
};

foreach (@ARGV) {
	$filenames{$_} = { };
	if (!-f $_) {
		print STDERR "$_ does not exist.\n";
		$exists = 0;
	}
}

if (!%filenames) {
	die "No filenames specified\n";
}

if (!$exists) {
	die "One or more supplied filenames does not exist.\n";
}

# Read the vote's tally.dat file ...

my $vote = new Vote(name => $vote_name);
my $tally_lr = $vote->get_tally();
my @errors;
my $changes = 0;
my $multi_used;

# Now go through each item in the tally list

foreach my $t (@$tally_lr) {
	my $tf = $t->{path};
	my $status = $t->{status};

	if (exists $filenames{$tf}) {
		$filenames{$tf}->{hit} = 1;

		# It's one of the supplied arguments
		if ($opt_n) {
			if ($status !~ /^multi-.*/i) {
				push(@errors, "$tf status = $status (must be MULTI-.*)");
				next;
			}

			if ($multi_used ne '' && $status ne $multi_used) {
				push(@errors, "$tf status = $status (expecting $multi_used)");
				next;
			}

			$multi_used = $status;

			# It's a goer
			$t->{status} = 'NEW';
			$changes++;
		} else {
			if ($status !~ /^new/i) {
				# Not NEW, fail all updates
				push(@errors, "$tf status = $status (must be NEW)");
				next;
			}

			# It's a goer
			$t->{status} = $multi_group;
			$changes++;
		}

	}
}

# Check for filenames which weren't hit
foreach my $f (keys %filenames) {
	if (!exists $filenames{$f}->{hit}) {
		push(@errors, "$f not in tally.dat file");
	}
}

if (@errors) {
	foreach (@errors) {
		print STDERR "Error: $_\n";
	}
	die "Update aborted due to errors.\n";
}

if (!$changes) {
	die "No change to tally file.\n";
}

# Otherwise rewrite a new tally.dat file ...
my $vote_dir = $vote->ng_dir();

my $tally_path = "$vote_dir/tally.dat";

if (!open(T, ">$tally_path.new.$$")) {
	die "Unable to open $tally_path.new.$$ for write!";
}

foreach my $t (@$tally_lr) {
	printf T "%s %s %s %d %s %s\n",
		$t->{email},
		$t->{group},
		$t->{vote},
		$t->{ts},
		$t->{path},
		$t->{status};
};

close(T);

# Now rename the old and new files, and check into RCS

rename($tally_path, "$tally_path.old");
rename("$tally_path.new.$$", $tally_path);
system("ci -l $tally_path < /dev/null");

exit(0);
