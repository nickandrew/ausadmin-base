#!/usr/bin/perl
#	@(#) send-voters.pl [-r] tally_path < message
#
# $Source$
# $Revision$
# $Date$
#

my $real;

if ($ARGV[0] eq '-r') {
	$real = 1;
} else {
	$real = 0;
}

my $tally_path = shift @ARGV || die "Usage: send-voters.pl tally_path < message\n";

# Read the list of voters

if (!open(V, "<$tally_path")) {
	die "Unable to open $tally_path: $!\n";
}

my @recipients;

while (<V>) {
	chomp;
	my($email,$group,$vote,$timestamp,$path,$status) = split(/\s/);

	# vote is yes/no/abstain/forge (mostly uppercase)
	if ($vote =~ /^(yes|no|abstain)$/i) {
		push(@recipients, [$email, $timestamp]);
	}
}

close(V);

# Now read the header and body of the message

my @message = <STDIN>;

# print each address ...
foreach my $r (@recipients) {
	my $email = $r->[0];
	my $timestamp = $r->[1];

	if ($real) {
		sendmail($email, \@message, $timestamp);
	}
}

exit(0);

# -----------------------------------------------------------------------------

sub sendmail {
	my $recipient = shift;
	my $msg_ref = shift;
	my $vote_id = shift;

	$ENV{MAILHOST} = "aus.news-admin.org";
	$ENV{QMAILUSER} = "vote-return-$vote_id";
	if (!open ( MP, "|/usr/sbin/sendmail $recipient")) {
		die "MP failed";
	}

	print MP "To: $recipient\n";
	print MP @$msg_ref;

	close(MP);
}

sub usage {
	die "Usage: send-voters.pl tally-path < message-file\n";
}
