#!/usr/bin/perl -w
#	@(#) genresult.pl vote
#
# $Source$
# $Revision$
# $Date$

=head1 NAME

genresult.pl - Create the results file for a vote

=head1 SYNOPSIS

genresult.pl [-d] [-r] $newsgroup > tmp/result.$newsgroup
pgp-sign < tmp/result.$newsgroup > vote/$newsgroup/result

=head1 DESCRIPTION

This program creates the result file for a vote. Generally the name of the
vote is the same as the name of the corresponding newsgroup.

The previous revision of this program also signed the output. This no
longer happens, so the result file must be signed later by using
B<pgp-sign>.

B<-d> puts the program into debug mode.

B<-r> notes this result as a recount.

=cut

use Getopt::Std;

my %opts;
getopts('dr', \%opts);

my $debug=$opts{'d'};
my $recount = $opts{'r'};

my $postaddress = "aus group admin <ausadmin\@aus.news-admin.org>";
my $organization = "aus.* newsgroups administration, see http://aus.news-admin.org/";

my $vote = shift;

sub read1line {
	my($path) = @_;
	my($line);
	if (!open(F, $path)) {
		die "Can't open $path: $!";
	}
	chop($line = <F>);
	close(F);
	return $line;
}

sub readfile {
	my($path) = @_;
	my($line);
	if (!open(F, $path)) {
		die "Can't open $path: $!";
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
	my($first, $rest);
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

if ($vote eq '') {
	print STDERR "genresult.pl: No vote specified\n";
	exit(2);
}

if (!-d "vote/$vote") {
	print STDERR "genresult.pl: No such vote ($vote)\n";
	exit(3);
}

# Get vote end date and vote pass/fail rule
my $ts_start = read1line("vote/$vote/vote_start.cfg");
my $ts_end = read1line("vote/$vote/endtime.cfg");
my $voterule = read1line("vote/$vote/voterule");

# These are the files written at CFV time
my $ngline = read1line("vote/$vote/ngline");
# $rationale = readfile("vote/$vote/rationale");
my $charter = readfile("vote/$vote/charter");

# General config files
my $footer =  readfile("config/results.footer");

my($numer, $denomer, $minyes) = split(/\s+/, $voterule);

my $vote_start;
my $vote_end;

{
     my($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = gmtime($ts_start) 
	  or die "Can't get start date.";

     $year += 1900; $mon++;
     $vote_start = sprintf "%d-%02d-%02d %02d:%02d:%02d UTC", $year, $mon, $mday, $hour, $min, $sec;
     
}

{
     my ($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = gmtime($ts_end);
     $year += 1900; $mon++;
     $vote_end = sprintf "%d-%02d-%02d %02d:%02d:%02d UTC", $year, $mon, $mday, $hour, $min, $sec;
     
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
if (time() < $ts_end) {
	die "genresult.pl: Vote $vote not finished yet.\n";
}

my %voters;
my %yes;
my %no;
my %abstain;
my %forge;
my %newsgroups;

# Open the tally file and munch it
if (!open(T, "<vote/$vote/tally.dat")) {
	die "genresult.pl: Vote $vote has no tally file.\n";
}

while (<T>) {
	my($email,$ng,$v,$ts,$path) = split;

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
		$forge{$ng} = 0;
	}

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
		push(@{$voters{$ng}}, "$email *");
	} else {
		push(@{$voters{$ng}}, "$email");
	}

}

close(T);

my($yvotes, $nvotes, $abstentions, $forgeries);

# Output results
foreach my $ng (sort (keys %newsgroups)) {

	my $status;
	my $subjstat;

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

	if ($forge{$ng} == 0) {
		$forgeries = "no forgeries";
	} elsif ($forge{$ng} == 1) {
		$forgeries = "1 forgery";
	} else {
		$forgeries = "$forge{$ng} forgeries";
	}


	# This stuff goes into the header

	print "Newsgroups: aus.general,aus.net.news\n";
	print "From: $postaddress\n";
	print "Organization: $organization\n";
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
		pass_msg($ng);
	} else {
		fail_msg($ng);
	}

	# This sucks. It's inside a loop.
	exit(0);
}

sub pass_msg() {
	my $ng = shift;

	my @body;

	# Formatted line
	my $line = "The newsgroup $ng has passed its vote by $yes{$ng} YES $yvotes to $no{$ng} NO $nvotes. There were $abstain{$ng} $abstentions and $forgeries detected.";
	push(@body, format_para($line));
	push(@body, "");

	push(@body, format_para("For a group to pass, YES votes must be at least $numer/$denomer of all valid (YES and NO) votes. There must also be at least $minyes more YES votes than NO votes. Abstentions and Forgeries do not affect the outcome."));
	push(@body, "");

	push(@body, format_para("A five-day discussion period follows this announcement. If no serious allegations of voting irregularities are raised, the aus.* newsgroups maintainer will issue the newgroup message shortly afterward."));

	push(@body, "");

	push(@body, format_para("Votes marked with an asterisk were detected as forgeries and were not counted in the vote."));
	push(@body, "");

	push(@body, "Newsgroups line:\n$ngline\n");

	push(@body, "The voting period started at: $vote_start");
	push(@body, "The voting period ended at:   $vote_end\n");

#	if (defined($rationale) && $rationale ne "") {
#		push(@body, "RATIONALE:");
#		push(@body, $rationale);
#	}

	if ($charter ne "") {
		push(@body, "\nCHARTER from CFV:");
		push(@body, $charter);
	}

	push(@body, "\nVOTERS:");
	foreach my $voter (sort @{$voters{$ng}}) {
		push(@body, "  $voter");;
	}
	push(@body, "");
	push(@body, $footer);

	foreach my $l (@body) {
		print "$l\n";
	}

	makegroup($ng,$ts_end + 5 * 86400);

	setposts($ng,"post.real",$ts_end + 5 * 86400, 5 * 86400, 3);
	setposts($ng,"post.fake.phil",$ts_end + 10 * 86400, 5 * 86400, 3);
	setposts($ng,"post.fake.robert",$ts_end + 15 * 86400, 5 * 86400, 3);
}

sub fail_msg() {
	my $ng = shift;

	my @body;

	# Formatted line
	my $line = "The newsgroup $ng has Failed its vote by $yes{$ng} YES $yvotes to $no{$ng} NO $nvotes. There were $abstain{$ng} $abstentions and $forgeries detected.";
	push(@body, format_para($line));
	push(@body, "");

	push(@body, format_para("For a group to pass, YES votes must be at least $numer/$denomer of all valid (YES and NO) votes. There must also be at least $minyes more YES votes than NO votes. Abstentions and Forgeries do not affect the outcome."));
	push(@body, "");

	push(@body, "\nVOTERS:");
	foreach my $voter (sort @{$voters{$ng}}) {
		push(@body, "  $voter");;
	}
	push(@body, "");
	push(@body, $footer);

	foreach my $l (@body) {
		print "$l\n";
	}
}

sub setposts {
	my ($groupname,$filename,$firstpostdate,$interval,$count)=@_;
  
	local *POST;

	return if $debug;

	if (not open (POST,">>vote/$vote/$filename")) {
		die "Unable to mark group $vote as passed: $filename\n";
	}
    
	print POST "$groupname\t$firstpostdate\t$interval\t$count\n";
	close POST;
}

sub makegroup {
  my $ng = shift;
  my $start = shift;

  local *CREATE;

  my $fn = "vote/$vote/group.creation.date";
  open (CREATE,">>$fn") 
    or die "Can't open $fn: $!";

  print CREATE "$start\n";

  close CREATE;
}


