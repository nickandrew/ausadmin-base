#!/usr/bin/perl
#	@(#) check-voters.pl vote-name voter-state-file < message-file
#
# $Source$
# $Revision$
# $Date$
#

=head1 NAME

check-voters.pl - Send a test email to all voters in a vote

=head1 SYNOPSIS

 check-voters.pl vote-name voter-state-file < message-file

 e.g. check-voters.pl aus.business data/voter-state < config/voter-check.msg

=head1 DESCRIPTION

This program sends a message to everybody who voted for B<vote-name>
and who has not been checked recently (180 days) as listed in
B<voter-state-file>.

The timestamp of all checked voters is updated to reflect the
latest time the email address was sent a message. In other words,
if an email address is sent a message, then its timestamp is updated.

This means that an address which votes regularly will be checked
at most once every 6 months; new (or one-off) voters will be
checked the first time they vote.

=cut

use lib 'bin';
use Vote qw();
use VoterState qw();
use Newsgroup qw();

my $newsgroup = shift @ARGV || die "No newsgroup name supplied";
my $voters_file = shift @ARGV || die "No voters file supplied";

die "Invalid newsgroup name <$newsgroup>" if (!Newsgroup::validate($newsgroup));

my $no_check_id = '-OLD-';

my $vstate = new VoterState();

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

	next if ($status eq 'FORGE' || $status eq 'INVALID');

	# Now check if we checked them before
	my $vs = $vstate->checkEmail($email);
	my $check_id;
	if (defined $vs) {
		if ($vs->{timestamp} !~ /^\d+$/) {
			print STDERR "Invalid timestamp $vs->{timestamp} for $email (ignoring)\n";
			next;
		}

		if ($vs->{state} eq 'OK') {
			# Don't recheck OK ones for a long time
			if ($vs->{timestamp} > $check_cutoff_ts) {
				my $diff = int(($now - $vs->{timestamp})/86400);
				print STDERR "Ignoring $email - checked $diff days ago.\n";
				next;
			}
		}

		$check_id = $vs->{check_id};
	}

	print STDERR "Checking $email ($check_id)\n";



	# If none supplied in file, generate a random one
	if ($check_id eq '' || $check_id eq $no_check_id) {
		$check_id = VoteState::randomCheckID();
	}

	# Otherwise, need to check them
	push(@recipients, [$email, $check_id]);

	# And mark they've been checked
	# KLUDGE ... this is dodgy ... what do we do when they fail a check?
	# If they fail a check, remove them from the voter_state file... ?
	$vs->{timestamp} = $now;
	$vs->{state} = 'OK';
	$vs->{check_id} = $check_id;
	$vstate->{updated} = 1;
}

close(V);

# Save the updated voters file
$vstate->save();

# Now rename to update and keep history
rename("$voters_file.$$", "$voters_file");
system("ci -l '-mUpdated by check-voters.pl' $voters_file");

# Now read the header and body of the message

my @message = <STDIN>;

# print each address ...
foreach my $r (@recipients) {
	my $email = $r->[0];
	my $check_id = $r->[1];

	sendmail($email, \@message, $check_id);
}

exit(0);

# -----------------------------------------------------------------------------

sub sendmail {
	my $recipient = shift;
	my $msg_ref = shift;
	my $check_id = shift;

	# Setup our return address for bounces
	my $verp = $check_id;
	# $verp =~ s/\@/=/g;
	# $verp =~ s/[^a-zA-Z0-9-._=]//g;

	$ENV{MAILHOST} = "aus.news-admin.org";
	$ENV{QMAILUSER} = "vote-return-$verp";

	if (!open(MP, "|/usr/sbin/sendmail $recipient")) {
		die "Open pipe to sendmail failed";
	}

	print MP "From: ausadmin vote checker <$ENV{QMAILUSER}\@$ENV{MAILHOST}>\n";
	print MP "To: $recipient\n";
	print MP "Reply-To: <$ENV{QMAILUSER}\@$ENV{MAILHOST}>\n";
	print MP @$msg_ref;

	close(MP);
}

sub usage {
	die "Usage: check-voters.pl newsgroup-name voter-state-file < message-file\n";
}
