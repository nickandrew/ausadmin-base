#!/usr/bin/perl
#	groupresult.pl vote
#
# $Source$
# $Revision$
# $Date$

use Ausadmin;

my $votedir = "vote";

my $vote = $ARGV[0];

my $now = time();

# sub read1line {
# 	my($path) = @_;
# 	my($line);
# 	if (!open(F, $path)) {
# 		return "";
# 	}
# 	chop($line = <F>);
# 	close(F);
# 	return $line;
# }

if ($vote eq "") {
	print "groupresult.pl: No vote specified\n";
	exit(2);
}

if (!-d "vote/$vote") {
	print "groupresult.pl: No such vote ($vote)\n";
	exit(3);
}

# Get vote end date and vote pass/fail rule
my $end_date = Ausadmin::read1line("vote/$vote/endtime.cfg");
my $voterule = Ausadmin::read1line("vote/$vote/voterule");
my($numer, $denomer, $minyes) = split(/\s+/, $voterule);
my $rc = 0;
my %tally;

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
	my($email,$ng,$v,$ts,$path,$status) = split;

	if (!exists $tally{$ng}) {
		$tally{$ng} = {
			'invalid' => 0,
			'yes' => 0,
			'no' => 0,
			'abstain' => 0,
			'voters' => [],
			'invalid_voters' => []
		};
	}

	if ($v ne "YES" && $v ne "NO" && $v ne "ABSTAIN") {
		$tally{$ng}->{'invalid'}++;
		push(@{$tally{$ng}->{'invalid_voters'}}, $email);
		print STDERR "Unknown vote: $v (in $vote)\n";
		next;
	}

	if ($status =~ /^(FORGE|INVALID|MULTI)/) {
		$tally{$ng}->{'invalid'}++;
		push(@{$tally{$ng}->{'invalid_voters'}}, $email);
		next;
	}

	push(@{$tally{$ng}->{'voters'}}, $email);

	if ($v eq "YES") {
		$tally{$ng}->{'yes'}++;
	}

	if ($v eq "NO") {
		$tally{$ng}->{'no'}++;
	}

	if ($v eq "ABSTAIN") {
		$tally{$ng}->{'abstain'}++;
	}
}

close(T);

# Output results
foreach my $ng (sort (keys %tally)) {
	my $status;
	my $yes = $tally{$ng}->{'yes'};
	my $no = $tally{$ng}->{'no'};
	my $abstain = $tally{$ng}->{'abstain'};
	my $invalid = $tally{$ng}->{'invalid'};

	if (($yes >= ($yes + $no) * $numer / $denomer) && ($yes - $no >= $minyes)) {
		$status = "pass";
	} else {
		$status = "fail";
	}

	print "Newsgroup: $ng\n";
	print "Yes: $yes\n";
	print "No: $no\n";
	print "Abstain: $abstain\n";
	print "Invalid: $invalid\n";
	print "Status: $status\n";

	print "Voters:\n";

	foreach my $voter (sort @{$tally{$ng}->{'voters'}}) {
		printf "   %s\n", $voter;
	}

	if (@{$tally{$ng}->{'invalid_voters'}}) {
		print "Invalid Voters:\n";

		foreach my $voter (sort @{$tally{$ng}->{'invalid_voters'}}) {
			printf "   %s\n", $voter;
		}
	}

	print "\n";
}

