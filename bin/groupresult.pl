#!/usr/bin/perl
#	groupresult.pl vote
#
# $Source$
# $Revision$
# $Date$

$votedir = "vote";

$vote = $ARGV[0];

$now = time;

sub read1line {
	my($path) = @_;
	my($line);
	if (!open(F, $path)) {
		return "";
	}
	chop($line = <F>);
	close(F);
	return $line;
}

if ($vote eq "") {
	print "groupresult.pl: No vote specified\n";
	exit(2);
}

if (!-d "vote/$vote") {
	print "groupresult.pl: No such vote ($vote)\n";
	exit(3);
}

# Get vote end date and vote pass/fail rule
$end_date = read1line("vote/$vote/endtime.cfg");
$voterule = read1line("vote/$vote/voterule");
($numer, $denomer, $minyes) = split(/\s+/, $voterule);

# barf if control files don't exist or other error
if ($end_date eq "" || $minyes eq "") {
	print "groupresult.pl: Vote $vote not properly set up\n";
	print "end_date is $end_date\n";
	print "minyes is $minyes\n";
	exit(4);
}

# Ensure vote is actually finished
if ($now < $end_date) {
	print "groupresult.pl: Vote $vote not finished yet.\n";
	exit(5);
}

# Open the tally file and munch it
if (!open(T, "vote/$vote/tally.dat")) {
	print "groupresult.pl: Vote $vote has no tally file.\n";
	exit(6);
}

while (<T>) {
	($email,$ng,$v,$ts,$path) = split;
	if ($v ne "YES" && $v ne "NO" && $v ne "ABSTAIN") {
		print "Unknown vote: $v (in $vote)\n";
		$rc |= 16;
		next;
	}

	if (!defined($voters{$ng})) {
		$voters{$ng} = [];
	}

	push(@{$voters{$ng}}, $email);

	if ($v eq "YES") {
		$yes{$ng}++;
		$newsgroups{$ng} = 1;
	}

	if ($v eq "NO") {
		$no{$ng}++;
		$newsgroups{$ng} = 1;
	}

	if ($v eq "ABSTAIN") {
		$abstain{$ng}++;
		$newsgroups{$ng} = 1;
	}
}

close(T);

# Output results
foreach $ng (sort (keys %newsgroups)) {
	print "Newsgroup: $ng\n";
	print "  Yes: $yes{$ng}\n";
	print "  No: $no{$ng}\n";
	print "  Abstain: $abstain{$ng}\n";

	if (($yes{$ng} >= ($yes{$ng} + $no{$ng}) * $numer / $denomer) && ($yes{$ng} - $no{$ng} >= $minyes)) {
		$status = "pass";
	} else {
		$status = "fail";
	}

	print "  Status: $status ($yes{$ng}:$no{$ng})\n";

	print "  Voters:\n";

	foreach $voter (sort @{$voters{$ng}}) {
		printf "   %s\n", $voter;
	}
	print "\n";
}

