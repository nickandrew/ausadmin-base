#!/usr/bin/perl
#	@(#) check-voters.pl [-r] newsgroup-name < message-file | /bin/bash
#
# $Source$
# $Revision$
# $Date$
#

use lib 'bin';
use Vote;
use Newsgroup;

my $newsgroup = shift @ARGV || die "No newsgroup name supplied";

die "Invalid newsgroup name <$newsgroup>" if (!Newsgroup::validate($newsgroup));

my $vote = new Vote(name =>$newsgroup);
my $ng_dir = $vote->ng_dir();

# Read the list of voters
my $tally_path = "$ng_dir/tally.dat";

if (!open(V, "<$tally_path")) {
	die "Unable to open $tally_path: $!\n";
}

my @recipients;

while (<V>) {
	chomp;
	my($email,$group,$vote,$timestamp) = split(/\s/);

	# vote is yes/no/abstain/forge (mostly uppercase)
	# only yes and no votes affect the result.
	if ($vote =~ /^(yes|no)$/i) {
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

	sendmail($email, \@message, $timestamp);
}

exit(0);

# -----------------------------------------------------------------------------
sub sendmail {
	my $recipient = shift;
	my $msg_ref = shift;
	my $vote_id = shift;

	print "export MAILHOST=aus.news-admin.org\n";
	print "export QMAILUSER=vote-return-$vote_id\n";
	print "/usr/sbin/sendmail $recipient <<'__EOF__'\n";

	print "To: $recipient\n";

	print @$msg_ref;
	print "__EOF__\n\n";
}

sub usage {
	die "Usage: check-voters.pl newsgroup-name < message-file | /bin/bash\n";
}
