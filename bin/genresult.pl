#!/usr/bin/perl
#	genresult.pl vote

$votedir = "vote";

$vote = $ARGV[0];

$now = time;
$postaddress = "ausadmin\@aus.news-admin.org";
if (-f "/usr/bin/pgps") {
	$pgpcmd = "pgps -fat";
} else {
	$pgpcmd = "pgp -fast";
}

select(STDOUT); $| = 1;

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

sub readfile {
	my($path) = @_;
	my($line);
	if (!open(F, $path)) {
		return "";
	}
	while (<F>) {
		$line .= $_;
	}
	close(F);
	return $line;
}

# Join all lines into one and split them into a paragraph.

sub format_para {
	my($line) = @_;
	my($rest);
	my($last_space);
	my(@result);

	# Format as a paragraph, max 72 chars
	$line =~ tr/\n/ /;
	while (length($line) > 72) {
		$last_space = rindex($line, ' ', 72);
		if ($last_space > 0) {
			$first = substr($line, 0, $last_space);
			push(@result, $first);
			$rest = substr($line, $last_space + 1);
			$line = $rest;
		}
	}
	if ($line ne "") {
		push(@result, $line);
	}

	return @result;
}

if ($vote eq "") {
	print "genresult.pl: No vote specified\n";
	exit(2);
}

if (!-d "vote/$vote") {
	print "genresult.pl: No such vote ($vote)\n";
	exit(3);
}

# Get vote end date and vote pass/fail rule
$ts_start = read1line("vote/$vote/conf/posted.cfg");
$ts_end = read1line("vote/$vote/conf/group.cfg");
$ngline = read1line("vote/$vote/conf/ngline");
$voterule = read1line("vote/$vote/conf/voterule");
$rationale = readfile("vote/$vote/conf/rationale");
$charter = readfile("vote/$vote/conf/charter");
$footer =  readfile("vote/conf/results.footer");

($numer, $denomer, $minyes) = split(/\s+/, $voterule);

($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = gmtime($ts_start);
$year += 1900; $mon++;
$vote_start = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;

($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = gmtime($ts_end);
$year += 1900; $mon++;
$vote_end = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;

# barf if control files don't exist or other error
if ($ts_end eq "" || $minyes eq "") {
	print "genresult.pl: Vote $vote not properly set up\n";
	print "end_date is $ts_end\n";
	print "minyes is $minyes\n";
	exit(4);
}

# Ensure vote is actually finished
if ($now < $end_date) {
	print "genresult.pl: Vote $vote not finished yet.\n";
	exit(5);
}

# Open the tally file and munch it
if (!open(T, "vote/$vote/votes/tally.dat")) {
	print "genresult.pl: Vote $vote has no tally file.\n";
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
		$yes{$ng} = 0;
		$no{$ng} = 0;
		$abstain{$ng} = 0;
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

	if (($yes{$ng} >= ($yes{$ng} + $no{$ng}) * $numer / $denomer) && ($yes{$ng} - $no{$ng} >= $minyes)) {
		$status = "pass";
		$subjstat = "passes";
	} else {
		$status = "fail";
		$subjstat = "fails";
	}

	if ($yes{$ng} == 1) {
		$yvotes = "vote";
	} else {
		$yvotes = "votes";
	}

	if ($no{$ng} == 1) {
		$nvotes = "vote";
	} else {
		$nvotes = "votes";
	}

	if ($abstain{$ng} == 1) {
		$abstentions = "abstention";
	} else {
		$abstentions = "abstentions";
	}

	# This stuff goes into the header

	print "Newsgroups: aus.general,aus.net.news\n";
	print "From: aus group admin <ausadmin\@aus.news-admin.org>\n";
	print "Organization: aus.* newsgroups administration, see http://aus.news-admin.org/\n";
	print "X-PGPKey: at http://aus.news-admin.org/ausadmin.asc\n";
	print "Followup-To: aus.net.news\n";
	print "Subject: RESULT: $ng $subjstat vote $yes{$ng}:$no{$ng}\n";
	print "\n";

	# Pass or fail?
	if ($status eq "pass") {
		pass_msg();
		exit(0);
	} else {
		fail_msg();
		exit(0);
	}
}

sub pass_msg() {
	# Formatted line
	$line = "The newsgroup $ng has passed its vote by $yes{$ng} YES $yvotes to $no{$ng} NO $nvotes. There were $abstain{$ng} $abstentions.";
	push(@body, format_para($line));
	push(@body, "");

	push(@body, format_para("For a group to pass, YES votes must be at least $numer/$denomer of all valid (YES and NO) votes. There must also be at least $minyes more YES votes than NO votes. Abstentions do not affect the outcome."));
	push(@body, "");

	push(@body, format_para("A five-day discussion period follows this announcement. If no serious allegations of voting irregularities are raised, the aus.* newsgroups maintainer will issue the newgroup message shortly afterward."));
	push(@body, "");

	push(@body, "Newsgroups line:\n$ngline\n");

	push(@body, "The voting period started at: $vote_start UTC");
	push(@body, "The voting period ended at:   $vote_end UTC\n");

	if ($rationale ne "") {
		push(@body, "RATIONALE:");
		push(@body, $rationale);
	}

	if ($charter ne "") {
		push(@body, "\nCHARTER:");
		push(@body, $charter);
	}

	push(@body, "\nVOTERS:");
	foreach $voter (sort @{$voters{$ng}}) {
		push(@body, "  $voter");;
	}
	push(@body, "");
	push(@body, $footer);

	if (!open(P, "|$pgpcmd")) {
		print "Unable to open pipe to pgp!\n";
		exit(7);
	}

	foreach $l (@body) {
		print P "$l\n";
	}

	close(P);
}

sub fail_msg() {
}
