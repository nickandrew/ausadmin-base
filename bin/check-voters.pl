#!/usr/bin/perl
#	@(#) check-voters.pl newsgroup-name voters-file < message-file | /bin/bash
#
# $Source$
# $Revision$
# $Date$
#

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

while (<V>) {
	chomp;
	my($email,$group,$vote,$timestamp) = split(/\s/);

	# vote is yes/no/abstain/forge (mostly uppercase)
	# only yes and no votes affect the result.
	next unless ($vote =~ /^(yes|no)$/i);

	# Now check if we checked them before
	if (exists $voter_state{$email} && $voter_state{$email} =~ /^\d+$/) {
		# It's ok if check was less than 90 days ago
		next if ($now - $voter_state{$email} < 86400 * 90);
	}

	# Otherwise, need to check them
	push(@recipients, [$email, $timestamp]);

	# And mark they've been checked
	# KLUDGE ... this is dodgy ... what do we do when they fail a check?
	if (!exists $voter_state{$email}) {
		$voter_state{$email} = $now;
	}
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

	print "export MAILHOST=aus.news-admin.org\n";
	print "export QMAILUSER=vote-return-$vote_id\n";
	print "/usr/sbin/sendmail $recipient <<'__EOF__'\n";

	print "To: $recipient\n";
	print @$msg_ref;
	print "__EOF__\n\n";
}

sub usage {
	die "Usage: check-voters.pl newsgroup-name voters-file < message-file | /bin/bash\n";
}
