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

 check-voters.pl vote-name < message-file

 e.g. check-voters.pl aus.business < config/voter-check.msg

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

die "Invalid newsgroup name <$newsgroup>" if (!Newsgroup::validate($newsgroup));

my $no_check_id = '-OLD-';

my $vstate = new VoterState();

my $vote = new Vote(name =>$newsgroup);
my $ng_dir = $vote->ng_dir();

# Read the list of voters
my $tally_path = "$ng_dir/tally.dat";
my $new_tally_path = "$ng_dir/tally.dat.$$";

if (!open(V, "<$tally_path")) {
	die "Unable to open $tally_path: $!\n";
}

my @tally;
my @recipients;
my $now = time();
my $check_cutoff_ts = $now - 86400 * 180;
my $nobounce_ts = $now - 86400 * 3;

while (<V>) {
	chomp;
	my($email,$group,$vote,$timestamp,$path,$status) = split(/\s/);

	my $r = {
		email => $email,
		group => $group,
		vote => $vote,
		timestamp => $timestamp,
		path => $path,
		status => $status,
	};

	push(@tally, $r);

	# vote is yes/no/abstain/forge (mostly uppercase)
	# only yes and no votes affect the result.
	next unless ($vote =~ /^(yes|no)$/i);

	# I was going to ignore MULTI, but let's try keeping them in.
	# next unless ($status =~ /^NEW/i);

	next if ($status eq 'FORGE' || $status eq 'INVALID');

	# Now check if we checked them before
	my $vs = $vstate->getCheckRef($email);

	if (!defined $vs) {
		die "That isn't supposed to happen: $email";
	}

	if ($vs->{timestamp} !~ /^\d+$/) {
		print STDERR "Invalid timestamp $vs->{timestamp} for $email (ignoring)\n";
		next;
	}

	# If no bounce after 3 days, NEW -> OK
	if ($vs->{state} eq 'NEW' && $vs->{timestamp} < $nobounce_ts) {
		$vstate->set($email, 'state', 'OK');
	}

	# If the state is NEW and the timestamp is recent ( <3 days ago)
	# then they have already been sent a message


	if ($vs->{state} eq 'OK' && $vs->{timestamp} < $check_cutoff_ts) {
		# This is a stale OK
		print "Check for $email is stale\n";
		$vstate->set($email, 'state', 'NEW');
		push(@recipients, $vs);
	}

	if ($vs->{state} eq 'OK' && $status eq 'NEW') {
		print "Status of $email set to OK\n";
		$r->{status} = $status = 'OK';
	}

	if ($vs->{state} eq 'BOUNCE' && $status eq 'NEW') {
		print "$email status to INVALID\n";
		$r->{status} = $status = 'INVALID';
	}

}

close(V);

# Save the updated voters file
$vstate->save();

# Save the updated tally file
open(NV, ">$new_tally_path");
foreach my $r (@tally) {
	print NV join(' ',
		$r->{email},
		$r->{group},
		$r->{vote},
		$r->{timestamp},
		$r->{path},
		$r->{status},
	), "\n";
}
close(NV);

system("ci -l '-mOriginal tally path' $tally_path");
rename($new_tally_path, $tally_path);
system("ci -l '-mAfter check-voters' $tally_path");

# Send any check messages
if (@recipients) {
	die "Not sending any messages";
	# Now read the header and body of the message
	my @message = <STDIN>;

	# print each address ...
	foreach my $vs (@recipients) {
		my $email = $vs->{email};
		my $check_id = $vs->{check_id};
		print STDERR "Sending to $email ($check_id)\n";

		sendmail($email, \@message, $check_id);
	}
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
