#!/usr/bin/perl
#	@(#) check-voters.pl vote-name voters-file < message-file
#
# $Source$
# $Revision$
# $Date$
#

=head1 NAME

check-voters.pl - Send a test email to all voters in a vote

=head1 SYNOPSIS

 check-voters.pl vote-name voters-file < message-file

=head1 DESCRIPTION

This program sends a message to everybody who voted for B<vote-name>
and who has not been checked recently (180 days) as listed in
B<voters-file>.

The timestamp of all checked voters is updated to reflect the
latest time the email address was sent a message. In other words,
if an email address is sent a message, then its timestamp is updated.

This means that an address which votes regularly will be checked
at most once every 6 months; new (or one-off) voters will be
checked the first time they vote.

=cut

use lib 'bin';
use Vote;
use Newsgroup;

my $newsgroup = shift @ARGV || die "No newsgroup name supplied";
my $voters_file = shift @ARGV || die "No voters file supplied";

die "Invalid newsgroup name <$newsgroup>" if (!Newsgroup::validate($newsgroup));

my %voter_state;

open(VF, "<$voters_file") or die "Unable to open $voters_file: $!";
while (<VF>) {
	chomp;
	my($email,$state) = split;
	$voter_state{$email} = $state;
}
close(VF);

my $vote = new Vote(name =>$newsgroup);
my $ng_dir = $vote->ng_dir();

# Read the list of voters
my $tally_path = "$ng_dir/tally.dat";

if (!open(V, "<$tally_path")) {
	die "Unable to open $tally_path: $!\n";
}

my @recipients;
my $now = time();
my $check_cutoff_ts = $now - 86400 * 180;

while (<V>) {
	chomp;
	my($email,$group,$vote,$timestamp,$path,$status) = split(/\s/);

	# vote is yes/no/abstain/forge (mostly uppercase)
	# only yes and no votes affect the result.
	next unless ($vote =~ /^(yes|no)$/i);

	# I was going to ignore MULTI, but let's try keeping them in.
	# next unless ($status =~ /^NEW/i);

	# Now check if we checked them before
	if (exists $voter_state{$email} && $voter_state{$email} =~ /^\d+$/) {
		# It's ok if last check was recent
		if ($voter_state{$email} > $check_cutoff_ts) {
			my $diff = int(($now - $voter_state{$email})/86400);
			print STDERR "Ignoring $email - checked $diff days ago.\n";
			next;
		}
	}

	print STDERR "Checking $email\n";

	# Otherwise, need to check them
	push(@recipients, [$email, $timestamp]);

	# And mark they've been checked
	# KLUDGE ... this is dodgy ... what do we do when they fail a check?
	# If they fail a check, remove them from the voter_state file...
	$voter_state{$email} = $now;
}

close(V);

# Now update the voter_state file
open(VF, ">$voters_file") or die "Unable to open $voters_file for write: $!";
foreach my $email (sort (keys %voter_state)) {
	print VF "$email $voter_state{$email}\n";
}
close(VF);

# Now read the header and body of the message

my @message = <STDIN>;

# print each address ...
foreach my $r (@recipients) {
	my $email = $r->[0];
	my $timestamp = $r->[1];

	sendmail($email, \@message, $timestamp);
}

exit(0);

# -----------------------------------------------------------------------------

sub sendmail {
	my $recipient = shift;
	my $msg_ref = shift;
	my $vote_id = shift;

	# Setup our return address for bounces

	$ENV{MAILHOST} = "aus.news-admin.org";
	$ENV{QMAILUSER} = "vote-return-$vote_id";

	if (!open(MP, "|/usr/sbin/sendmail $recipient")) {
		die "Open pipe to sendmail failed";
	}

	print MP "To: $recipient\n";
	print MP @$msg_ref;

	close(MP);
}

sub usage {
	die "Usage: check-voters.pl newsgroup-name voters-file < message-file\n";
}
