#!/usr/bin/perl -w
#	genresult.pl vote
#	$Revision$
#	$Date$

use Getopt::Std;
use vars '$opt_d';

getopts("d");

my $debug=$opt_d;

$votedir = "vote";
$postaddress = "aus group admin <ausadmin\@aus.news-admin.org>";

$vote = shift;
$recount = shift;

$now = time;
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
		die "Can't open $path";
	}
	chop($line = <F>);
	close(F);
	return $line;
}

sub readfile {
	my($path) = @_;
	my($line);
	if (!open(F, $path)) {
		die "Can't open $path";
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
	print STDERR "genresult.pl: No vote specified\n";
	exit(2);
}

if (!-d "vote/$vote") {
	print STDERR "genresult.pl: No such vote ($vote)\n";
	exit(3);
}

# Get vote end date and vote pass/fail rule
$ts_start = read1line("vote/$vote/starttime.cfg");
$ts_end = read1line("vote/$vote/endtime.cfg");
$ngline = read1line("vote/$vote/ngline");
$voterule = read1line("vote/$vote/voterule");
#$rationale = readfile("vote/$vote/rationale");
$charter = readfile("vote/$vote/charter");
$footer =  readfile("vote/conf/results.footer");

($numer, $denomer, $minyes) = split(/\s+/, $voterule);

{
     my ($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = gmtime($ts_start) 
	  or die "Can't get start date.";

     $year += 1900; $mon++;
     $vote_start = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
     
}
{
     my ($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = gmtime($ts_end);
     $year += 1900; $mon++;
     $vote_end = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
     
}

# barf if control files don't exist or other error
if (not ($ts_end && $minyes && $ts_start)) {
	print STDERR "genresult.pl: Vote $vote not properly set up\n";
	print STDERR "start_date is $ts_start\n";
	print STDERR "end_date is $ts_end\n";
	print STDERR "minyes is $minyes\n";
	exit(4);
}

# Ensure vote is actually finished
if ($now < $ts_end) {
	print STDERR "genresult.pl: Vote $vote not finished yet.\n";
	exit(5);
}

# Open the tally file and munch it
if (!open(T, "vote/$vote/tally.dat")) {
	print STDERR "genresult.pl: Vote $vote has no tally file.\n";
	exit(6);
}

while (<T>) {
	($email,$ng,$v,$ts,$path) = split;

	$v=uc($v);

	if ($v ne "YES" && $v ne "NO" && $v ne "ABSTAIN" && $v ne "FORGE") {
		print STDERR "Unknown vote: $v (in $vote)\n";
#		$rc |= 16;
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

	if ($v eq "FORGE") {
		$forge{$ng}++;
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

	if ($forge{$ng} == 1) {
	  $forgeries = "forged email";
	} else {
	  $forgeries = "forgeries";
	}


	# This stuff goes into the header

	print "Newsgroups: aus.general,aus.net.news\n";
	print "From: $postaddress\n";
	print "Organization: aus.* newsgroups administration, see http://aus.news-admin.org/\n";
	print "X-PGPKey: at http://aus.news-admin.org/ausadmin.asc\n";
	print "Followup-To: aus.net.news\n";
	if (not $recount) {
	  print "Subject: RESULT: $ng $subjstat vote $yes{$ng}:$no{$ng}\n"; 
	} else {
	  print "Subject: RECOUNT: $ng $subjstat vote $yes{$ng}:$no{$ng}\n"; 

	}
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
	$line = "The newsgroup $ng has passed its vote by $yes{$ng} YES $yvotes to $no{$ng} NO $nvotes. There were $abstain{$ng} $abstentions and $forge{$ng} $forgeries detected.";
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
		push(@body, "\nCHARTER from CFV:");
		push(@body, $charter);
	}

	push(@body, "\nVOTERS:");
	foreach $voter (sort @{$voters{$ng}}) {
		push(@body, "  $voter");;
	}
	push(@body, "");
	push(@body, $footer);

	if (!open(P, "|$pgpcmd")) {
		print STDERR "Unable to open pipe to pgp!\n";
		exit(7);
	}

	foreach $l (@body) {
		print P "$l\n";
	}

	close(P);

# 60 sec * 60 min * 24 hours * 5 days = 432000

	&setposts($ng,"post.real",$ts_end + 432000,432000,3);
	&setposts($ng,"post.fake.phil",$ts_end + 864000,432000,3);
	&setposts($ng,"post.fake.robert",$ts_end + 1296000,432000,3);
}

sub fail_msg() {
}

sub setposts {
  
  my ($groupname,$filename,$firstpostdate,$interval,$count)=@_;
  
  local *POST;

  return if $debug;

  if (not open (POST,">>vote/$vote/$filename")) {
    print STDERR "Unable to mark group as passed\n";
    exit(8);
  }
    
  print POST "$groupname\t$firstpostdate\t$interval\t$count\n";
  close POST;
  
}

