#!/usr/bin/perl
#	@(#) send-notify-email.pl - Send email to all voters
#	Usage: send-notify-email.pl newsgroup-name filename-to-send | /bin/bash
#
# $Id$

use lib '.', 'bin';
use Vote;
use Newsgroup;

my $newsgroup = shift @ARGV;
my $filename = shift @ARGV;

die "Invalid newsgroup name <$newsgroup>" if (!Newsgroup::validate($newsgroup));

my $vote = new Vote(name => $newsgroup);
my $vote_list = $vote->get_tally();

# $vote_list = [$v, $v, $v, ...]
# $v = { email => email_address, group => newsgroup, vote => YES|NO|ABSTAIN|FORGE, ts => 987654321 }

my $ng_dir = $vote->ng_dir();

if (!-f "$ng_dir/$filename") {
	die "No such file to send: $ng_dir/$filename";
}

# Read in the file

my $s = $vote->read_file($filename);

# Now send it out to each vote in the tally file

foreach my $v (@$vote_list) {
	my $email = $v->{email};

	print "/usr/sbin/sendmail $email <<'__EOF__'\n";
	# We set the To: address for each one
	print "To: $email\n";
	# Imagine some pgp signing shit in here
	print join('', @$s);
	print "__EOF__\n\n";
}

exit(0);
