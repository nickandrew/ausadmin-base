#!/usr/bin/perl
#	@(#) Tally.pm - A vote tally.dat file
#
# $Source$
# $Revision$
# $Date$
#

=head1 NAME

Tally - A vote tally.dat file

=head1 SYNOPSIS

my $tally = new Tally(name => $newsgroup);
$tally->remove($email);

=head1 DESCRIPTION

This module implements various functions to deal with the tally file.

=cut

package Tally;

use FileHandle;
use IO::File;
use Fcntl qw(:flock);

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	die "No name" if (!exists $self->{name});

	return $self;
}

=head2

C<$count = remove($email)>

Safely remove any lines matching the given email address from the tally
file. Returns the number of lines removed.

=cut

sub remove {
	my $self = shift;
	my $remove_email = shift;

	# Read the lines from the file
	my @lines;
	my $ng_dir = "vote/$self->{name}";
	die "No directory $ng_dir" if (!-d $ng_dir);

	my $tally_file = "$ng_dir/tally.dat";

	my $tf = new IO::File($tally_file, O_RDWR);
	die "Tally::remove - cannot open $tally_file: $!" if (!defined $tf);
	flock($tf, LOCK_EX);
	my $found = 0;

	# Now read all the lines
	while (<$tf>) {
		my($email,$newsgroup,$vote,$timestamp) = split(/\s/);
		if ($email eq $remove_email) {
			$found++;
			next;
		}
		push(@lines, $_);
	}

	# Now truncate and rewrite the file
	$tf->truncate(0);

	while (@lines) {
		$tf->print($_);
	}

	if (!$tf->close()) {
		die "Tally::remove() Error writing to $tally_file: $!";
	}

	return $found;
}

=head2

C<set_vote($email, $vote)>

Change the vote for a particular email address to the $vote specified.

=cut

sub set_vote {
	my $self = shift;
	my $email = shift;
	my $vote = shift;

	# Read the lines from the file
	my @lines;
	my $ng_dir = "vote/$self->{name}";
	die "No directory $ng_dir" if (!-d $ng_dir);

	my $tally_file = "$ng_dir/tally.dat";

	my $tf = new IO::File($tally_file, O_RDWR|O_APPEND);
	die "Tally::remove - cannot open $tally_file: $!" if (!defined $tf);
	flock($tf, LOCK_EX);
	my $found = 0;

	# Now read all the lines
	while (<$tf>) {
		my($v_email,$v_newsgroup,$v_vote,$v_timestamp) = split(/\s/);
		if ($email eq $v_email) {
			# Set the vote now
			push(@lines, "$v_email $v_newsgroup $vote $v_timestamp\n");
			$found++;
			next;
		}
		push(@lines, $_);
	}

	# Now truncate and rewrite the file
	# P.S. need seek(0,0) after truncate if not using O_APPEND
	$tf->truncate(0);

	foreach (@lines) {
		$tf->print($_);
	}

	if (!$tf->close()) {
		die "Tally::remove() Error writing to $tally_file: $!";
	}

	return $found;
}

1;
