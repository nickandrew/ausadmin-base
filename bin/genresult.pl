#!/usr/bin/perl -w
#	@(#) genresult.pl vote
#
# $Source$
# $Revision$
# $Date$

=head1 NAME

genresult.pl - Create the results file for a vote

=head1 SYNOPSIS

genresult.pl [B<-d>] [B<-r>] $votename > tmp/result.$votename
pgp-sign < tmp/result.$votename > vote/$votename/result
bin/post.pl < vote/$votename/result

=head1 DESCRIPTION

This program creates the result file for a vote. Generally the name of the
vote is the same as the name of the corresponding newsgroup to be created.

The previous revision of this program also signed the output. This no
longer happens, so the result file must be signed later by using
B<pgp-sign>.

B<-d> puts the program into debug mode.

B<-r> notes this result as a recount.

=cut

use Getopt::Std;
use lib 'bin';
use Ausadmin;
use Vote;
use Message;

my %opts;
getopts('dr', \%opts);

my $debug = $opts{'d'};
my $recount = $opts{'r'};

my $votename = shift;

if ($votename eq '') {
	print STDERR "genresult.pl: No vote specified\n";
	exit(2);
}

if (!-d "vote/$votename") {
	print STDERR "genresult.pl: No such vote ($votename)\n";
	exit(3);
}

if (-f "vote/$votename/vote_cancel.cfg") {
	die "genresult.pl: Vote $votename was cancelled\n";
}

my $vote = new Vote(name => $votename);

# Get vote end date and vote pass/fail rule
my $ts_start = Ausadmin::read1line("vote/$votename/vote_start.cfg");
my $ts_end = Ausadmin::read1line("vote/$votename/endtime.cfg");
my $voterule = Ausadmin::read1line("vote/$votename/voterule");

# These are the files written at CFV time
my $ngline = Ausadmin::read1line("vote/$votename/ngline");
# $rationale = Ausadmin::readfile("vote/$votename/rationale");
my $charter = Ausadmin::readfile("vote/$votename/charter");

# General config files
my $footer = Ausadmin::readfile("config/results.footer");

my($numer, $denomer, $minyes) = split(/\s+/, $voterule);

my $vote_start;
my $vote_end;

{
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = gmtime($ts_start);

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
	print STDERR "genresult.pl: Vote $votename not properly set up\n";
	print STDERR "start_date is $ts_start\n";
	print STDERR "end_date is $ts_end\n";
	print STDERR "minyes is $minyes\n";
	exit(4);
}

# Ensure vote is actually finished
if (time() < $ts_end) {
	die "genresult.pl: Vote $votename not finished yet.\n";
}

my %voters;
my %yes;
my %no;
my %abstain;
my %forge;
my %multi;
my %total;
my %invalid = ('YES' => 0, 'NO' => 0, 'ABSTAIN' => 0);

my $tally_lr = $vote->get_tally();

foreach my $vline (@$tally_lr) {
	my $email = $vline->{email};
	my $ng = $vline->{group};
	my $v = $vline->{vote};
	my $ts = $vline->{ts};
	my $path = $vline->{path};
	my $status = $vline->{status};

	if ($ng ne $votename) {
		print STDERR "Ignoring vote from $email for different group $ng (expecting $votename)\n";
		next;
	}

	$v=uc($v);

	if ($v ne "YES" && $v ne "NO" && $v ne "ABSTAIN" && $v ne "FORGE") {
		print STDERR "Unknown vote: $v ($email in $votename)\n";
#		$rc |= 16;
		next;
	}

	$email =~ s/\@/ at /;

	if (!defined($voters{$ng})) {
		$voters{$ng} = [];
		$total{$ng} = 0;
		$yes{$ng} = 0;
		$no{$ng} = 0;
		$abstain{$ng} = 0;
		$forge{$ng} = 0;
		$multi{$ng} = 0;
	}

	$total{$ng}++;

	if ($status =~ /^MULTI/i) {
		$multi{$ng}++;
		push(@{$voters{$ng}}, "$email MULTI");
		$invalid{$v}++;
		next;
	}

	if ($status =~ /^FORGE/i) {
		$forge{$ng}++;
		push(@{$voters{$ng}}, "$email INVALID");
		$invalid{$v}++;
		next;
	}

	if ($v eq "FORGE") {
		$forge{$ng}++;
		push(@{$voters{$ng}}, "$email INVALID");
		$invalid{$v}++;
		next;
	}

	if ($v eq "YES") {
		$yes{$ng}++;
	} elsif ($v eq "NO") {
		$no{$ng}++;
	} elsif ($v eq "ABSTAIN") {
		$abstain{$ng}++;
	}

	push(@{$voters{$ng}}, "$email");

}

my($yvotes, $nvotes, $abstentions, $forgeries);

# Output results
my $ng = $votename;

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


# Make message header from defaults

my %header;

if (not $recount) {
	$header{Subject} = "RESULT: $ng $subjstat vote $yes{$ng}:$no{$ng}";
} else {
	$header{Subject} = "RECOUNT: $ng $subjstat vote $yes{$ng}:$no{$ng}";
}

Ausadmin::print_header(\%header);

# Pass or fail?
pass_msg($ng, ($status eq 'pass'));

# Tack an analysis of multi-votes onto the end

analyse_multi($ng, $tally_lr);

# Footer
my @body;

push(@body, "");
push(@body, $footer);

foreach my $l (@body) {
	print "$l\n";
}

exit(0);

sub pass_msg() {
	my $ng = shift;
	my $pass = shift;

	my @body;
	my $line;

	# Formatted line
	if ($pass) {
		$line = "The newsgroup $ng has passed its vote by $yes{$ng} YES $yvotes to $no{$ng} NO $nvotes. There were $abstain{$ng} $abstentions and $forgeries detected.";
	} else {
		$line = "The newsgroup $ng has failed its vote by $yes{$ng} YES $yvotes to $no{$ng} NO $nvotes. There were $abstain{$ng} $abstentions and $forgeries detected.";
	}

	push(@body, format_para($line));
	push(@body, "");

	push(@body, sprintf("Total number of votes received:   %5d", $total{$ng}));
	push(@body, sprintf("Number of YES votes:              %5d", $yes{$ng}));
	push(@body, sprintf("Number of NO votes:               %5d", $no{$ng}));
	push(@body, sprintf("Number of ABSTAIN votes:          %5d", $abstain{$ng}));

	if ($invalid{'YES'} > 0 && $invalid{'NO'} > 0) {
		# Don't reveal counts of invalid votes if they are all
		# of the same type
		push(@body, sprintf("Number of invalid YES votes:      %5d", $invalid{'YES'}));
		push(@body, sprintf("Number of invalid NO votes:       %5d", $invalid{'NO'}));
		push(@body, sprintf("Number of invalid ABSTAIN votes:  %5d", $invalid{'ABSTAIN'}));
	}

	push(@body, "");


	push(@body, format_para("For a group to pass, YES votes must be at least $numer/$denomer of all valid (YES and NO) votes. There must also be at least $minyes more YES votes than NO votes. Abstentions, forgeries and multiple votes do not affect the outcome."));
	push(@body, "");

	if ($pass) {
		push(@body, format_para("A five-day discussion period follows this announcement. If no serious allegations of voting irregularities are raised, the aus.* newsgroups maintainer will issue the newgroup message shortly afterward."));

		push(@body, "");
	}

	push(@body, format_para("Votes marked as invalid or multi-votes were not counted in the result."));
	push(@body, "");

	push(@body, "The voting period started at: $vote_start");
	push(@body, "The voting period ended at:   $vote_end\n");

	push(@body, "\nVOTES RECEIVED:");
	foreach my $voter (sort @{$voters{$ng}}) {
		push(@body, "  $voter");;
	}

	foreach my $l (@body) {
		print "$l\n";
	}
}

sub setposts {
	my ($groupname,$filename,$firstpostdate,$interval,$count)=@_;

	local *POST;

	return if $debug;

	if (not open (POST,">>vote/$votename/$filename")) {
		die "Unable to mark group $votename as passed: $filename\n";
	}

	print POST "$groupname\t$firstpostdate\t$interval\t$count\n";
	close POST;
}

sub makegroup {
	my $ng = shift;
	my $start = shift;

	local *CREATE;

	my $fn = "vote/$votename/group.creation.date";
	open (CREATE,">>$fn")
		or die "Can't open $fn: $!";

	print CREATE "$start\n";

	close CREATE;
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

sub analyse_multi {
	my $ng = shift;
	my $tally_lr = shift;

	# First fill a hash with each group of multi-votes
	my %multi;

	foreach my $t (@$tally_lr) {
		next unless ($t->{status} =~ /^MULTI/i);

		push(@{$multi{$t->{status}}}, $t);
	}

	if (!%multi) {
		print "No multiple votes were received.\n";
		return;
	}

	print "\n\n";
	print "Multiple vote report follows. The meaning of this report is documented\n";
	print "at http://aus.news-admin.org/Faq/multi-vote.html\n\n";

	foreach my $k (sort (keys %multi)) {
		print "  Multiple vote group: $k\n";
		foreach my $t (@{$multi{$k}}) {
			my $path = $t->{path};

			my $m = new Message();
			$m->parse_file($path);

			# Calculate the relevant IP addresses
			my $ips = calculate_ips($m);

			# And get the From line
			my $from = $m->first_header('from');
			$from = Ausadmin::email_obscure($from);

			my($sec,$min,$hour,$mday,$mon,$year) = localtime($t->{ts});
			$mon++; $year += 1900;
			my $ts = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;
			printf "    Date: %s\n", $ts;
			printf "    %s\n", $from;
			printf "    IPs:  %s\n", $ips;
			print "\n";
		}

		print "\n";
	}

	print "\n";
}

sub calculate_ips {
	my $m = shift;
	my %ips;

#	print STDERR "Analysing $path\n";

	my $data_hr = $m->header_info();
	if (exists $data_hr->{ip}) {
		my $lr = $data_hr->{ip};
		foreach (@$lr) {
			$ips{$_} = 1;
		}
	}

	# Now go through the received headers and find all IPs
	my @headers = $m->headers();

	foreach my $hdr (@headers) {
		next unless ($hdr =~ /^Received: /);
		my $data_hash = $m->check_received($hdr);

		# Interesting data type is src-ip

		if (exists $data_hash->{'src-ip'}) {
			my $lr = $data_hash->{'src-ip'};
			foreach (@$lr) {
				$ips{$_} = 1;
			}
		}
	}

	# Now build a string containing the unique IP addresses
	return join(' ', sort(keys %ips));
}

