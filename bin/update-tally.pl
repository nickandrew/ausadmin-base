#!/usr/bin/perl -w
#	@(#) $Header$
#
#	Annotate the tally file with any known invalid votes

use lib 'bin';
use VoterState qw();

my $tally_path = shift @ARGV;
my $new_tally = shift @ARGV;

my $vs = new VoterState();
my $now = time();
my $old_bounce = $now - 28 * 86400;

open(TIN, "<$tally_path") || die "Unable to open $tally_path for read: $!";
open(TOUT, ">$new_tally") || die "Unable to open $new_tally for write: $!";

while (<TIN>) {
	chomp;
	my($email,$newsgroup,$vote,$timestamp,$filename,$status) = split;

	$email = lc($email);

	if ($status eq 'NEW') {
		my $r = $vs->checkEmail($email);

		if (!defined $r) {
			print "Email $email is not in the voter-state file!\n";
			$vs->getCheckRef($email);
		}
		else {
			if ($r->{state} eq 'BOUNCE') {
				if ($r->{timestamp} >= $old_bounce) {
					print "Email $email bounced recently, update tally state to BOUNCE\n";
					$status = 'BOUNCE';
				} else {
					print "Email $email was an old bounce\n";
				}
			} else {
				print "Email $email is OK\n";
			}
		}
	}

	print TOUT join(' ',
		$email,
		$newsgroup,
		$vote,
		$timestamp,
		$filename,
		$status,
	), "\n";
}

$vs->save();

exit(0);
