#!/usr/bin/perl
#	@(#) send-voters.pl [-r] tally_path 'subject' < message
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

my $tally_path = shift @ARGV || die "Usage: send-voters.pl tally_path 'subject'\n";
my $subject = shift @ARGV || die "Usage: send-voters.pl tally_path 'subject'\n";

# Read the list of voters

if (!open(V, "<$tally_path")) {
	die "Unable to open $tally_path: $!\n";
}

my @recipients;

while (<V>) {
	chomp;
	my($email,$group,$vote,$timestamp) = split(/\s/);

	# vote is yes/no/abstain/forge (mostly uppercase)
	if ($vote =~ /^(yes|no|abstain)$/i) {
		push(@recipients, $email);
	}
}

close(V);

# Now read the body of the message

my @message = <STDIN>;

# print each address ...
foreach my $email (@recipients) {
	print "To: $email\n";
	if ($real) {
		sendmail($email, $subject, \@message);
	}
}

exit(0);

# -----------------------------------------------------------------------------
sub sendmail {
	my $recipient = shift;
	my $subject = shift;
	my $msg_ref = shift;

	$ENV{'MAILHOST'}="aus.news-admin.org";
	if (!open ( MP, "|/usr/sbin/sendmail $recipient")) {
		die "MP failed";
	}

	print MP "From: ausadmin\@aus.news-admin.org (aus Newsgroup Administration)\n";
	print MP "To: $recipient\n";
	print MP "Subject: $subject\n";
	print MP "X-Automated-Reply: this message was sent by an auto-reply program\n";
	print MP "\n";

	print MP @$msg_ref;

	close(MP);
}
