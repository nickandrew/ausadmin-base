#!/usr/bin/perl -w
#	@(#) $Header$
#
# Email handler for returned vote acks (vote-return-xxxxxxxxxx address)

use lib 'bin';
use VoterState qw();

my $returned_votes = 'mail/returned-votes.new';

my $vs = new VoterState();

# The hash code is where we get our info, probably $EXT3
my $ext3 = $ENV{EXT3} || 'unknown';

my $email = $vs->idToEmail($ext3);
my $old_state = 'unknown';
my $new_state = 'unknown';

if ($email) {
	$old_state = $vs->getState($email);
	$new_state = 'BOUNCE';
	$vs->setState($email, $new_state);
	$vs->set($email, 'timestamp', time());
}

if (open(RV, ">$returned_votes")) {
	my @a;
	foreach my $v qw(LOCAL EXT EXT2 EXT3) {
		push(@a, "RETURNED: $v = $ENV{$v}");
	}

	print RV join(', ', @a), " $old_state -> BOUNCE\n";
	print RV <STDIN>;
	close(RV);
}

exit(0);
