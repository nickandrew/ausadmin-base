#!/usr/bin/perl
#	@(#) genresult.pl - Create the results file for a vote
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
use POSIX qw(:time_h);
use lib 'bin';
use Ausadmin;
use Vote;
use Message;

my %opts;
getopts('dr', \%opts);

my $debug = $opts{'d'};
my $opt_recount = $opts{'r'};

my $votename = shift @ARGV;
my $vote_dir = './vote';

if ($votename eq '') {
	print STDERR "genresult.pl: No vote specified\n";
	exit(2);
}

if (!-d "$vote_dir/$votename") {
	print STDERR "genresult.pl: No such vote ($votename)\n";
	exit(3);
}

if (-f "$vote_dir/$votename/vote_cancel.cfg") {
	die "genresult.pl: Vote $votename was cancelled\n";
}

if (! -f "$vote_dir/$votename/endtime.cfg") {
	die "genresult.pl: Vote $votename did not go to a vote\n";
}

if (-f "$vote_dir/$votename/vote_result") {
	die "genresult.pl: Vote $votename already has a vote_result file (delete it first)\n";
}

my $vote = new Vote(name => $votename);

# Get vote end date and vote pass/fail rule
my $ts_start = Ausadmin::read1line("$vote_dir/$votename/vote_start.cfg");
my $ts_end = Ausadmin::read1line("$vote_dir/$votename/endtime.cfg");
my $voterule = Ausadmin::read1line("$vote_dir/$votename/voterule");

# These are the files written at CFV time
my $ngline = Ausadmin::read1line("$vote_dir/$votename/ngline");
# $rationale = Ausadmin::readfile("$vote_dir/$votename/rationale");
my $charter = Ausadmin::readfile("$vote_dir/$votename/charter");

# General config files
my $footer = Ausadmin::readfile("config/results.footer");

my($numer, $denomer, $minyes) = split(/\s+/, $voterule);


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

# Setup defaults for the counting

my $vote_info = {
	valid_tally => { 'YES' => 0, 'NO' => 0, 'ABSTAIN' => 0 },
	invalid_tally => { 'YES' => 0, 'NO' => 0, 'ABSTAIN' => 0 },
	valid_count => 0,
	invalid_count => 0,
	multi_count => 0,
	total => 0,
	voters => [ ],
	vote_result => 'UNKNOWN',
};

my $tally_lr = $vote->get_tally();

foreach my $vline (@$tally_lr) {
	my $email = $vline->{email};
	my $ng = $vline->{group};
	my $v = $vline->{vote};
	my $ts = $vline->{ts};
	my $path = $vline->{path};
	my $status = $vline->{status};

#  Oops ... votes may be renamed later, we don't want to foul the calculation
#	if ($ng ne $votename) {
#		print STDERR "Ignoring vote from $email for different vote $ng (expecting $votename)\n";
#		next;
#	}

	$v=uc($v);

	if ($v ne 'YES' && $v ne 'NO' && $v ne 'ABSTAIN' && $v ne 'FORGE') {
		print STDERR "Unknown vote: $v ($email in $votename)\n";
#		$rc |= 16;
		next;
	}

	# This is for backwards compatibility

	if ($v eq 'FORGE') {
		$status = 'FORGE';
	}

	$vote_info->{total}++;

	if ($status =~ /^MULTI/i) {
		$vote_info->{multi_count}++;
		$vote_info->{invalid_count}++;
		push(@{$vote_info->{voters}}, "$email MULTI");
		$vote_info->{invalid_tally}->{$v}++;
		next;
	}

	if ($status =~ /^FORGE/i) {
		$vote_info->{invalid_count}++;
		push(@{$vote_info->{voters}}, "$email INVALID");
		$vote_info->{invalid_tally}->{$v}++;
		next;
	}

	# It's a valid vote, so add to the valid_tally etc...

	$vote_info->{valid_tally}->{$v}++;
	$vote_info->{valid_count}++;
	push(@{$vote_info->{voters}}, "$email");
}

# Quick access ...
my $yes = $vote_info->{valid_tally}->{'YES'} || 0;
my $no = $vote_info->{valid_tally}->{'NO'} || 0;
my $abstain = $vote_info->{valid_tally}->{'ABSTAIN'} || 0;

my($yvotes, $nvotes, $abstentions, $invalids);

# Output results
my $ng = $votename;

my $subjstat;

if (($yes >= ($yes + $no) * $numer / $denomer) && ($yes - $no >= $minyes)) {
	$vote_info->{'vote_result'} = "PASS";
	$subjstat = "passes";
} else {
	$vote_info->{'vote_result'} = "FAIL";
	$subjstat = "fails";
}

if ($yes == 1) {
	$yvotes = "vote";
} else {
	$yvotes = "votes";
}

if ($no == 1) {
	$nvotes = "vote";
} else {
	$nvotes = "votes";
}

if ($abstain == 1) {
	$abstentions = "abstention";
} else {
	$abstentions = "abstentions";
}

if ($vote_info->{invalid_count} == 0) {
	$invalids = "no invalid votes";
} elsif ($vote_info->{invalid_count} == 1) {
	$invalids = "1 invalid vote";
} else {
	$invalids = "$vote_info->{invalid_count} invalid votes";
}


# Make message header from defaults

my %header;

if (not $opt_recount) {
	$header{Subject} = "RESULT: $ng $subjstat vote $yes:$no";
} else {
	$header{Subject} = "RECOUNT: $ng $subjstat vote $yes:$no";
}

Ausadmin::print_header(\%header);

# Pass or fail?
pass_msg($ng, ($vote_info->{'vote_result'} eq 'PASS'));

# Tack an analysis of multi-votes onto the end

analyse_multi($ng, $tally_lr);

# Footer
my @body;

push(@body, "");
push(@body, $footer);

foreach my $l (@body) {
	print "$l\n";
}

# Now write the summary vote result:

write_vote_result($ng, $vote_info);


exit(0);

sub pass_msg {
	my $ng = shift;
	my $pass = shift;

	my @body;
	my $line;

	# Formatted line
	if ($pass) {
		$line = "The vote $ng has passed by $yes YES $yvotes to $no NO $nvotes. There were $abstain $abstentions and $invalids detected.";
	} else {
		$line = "The vote $ng has failed by $yes YES $yvotes to $no NO $nvotes. There were $abstain $abstentions and $invalids detected.";
	}

	push(@body, format_para($line));
	push(@body, "");

	push(@body, sprintf("Total number of votes received:   %5d", $vote_info->{total}));
	push(@body, sprintf("Number of YES votes:              %5d", $yes));
	push(@body, sprintf("Number of NO votes:               %5d", $no));
	push(@body, sprintf("Number of ABSTAIN votes:          %5d", $abstain));

	if ($vote_info->{invalid_tally}->{'YES'} > 0 && $vote_info->{invalid_tally}->{'NO'} > 0) {
		# Don't reveal counts of invalid votes if they are all
		# of the same type
		push(@body, sprintf("Number of invalid YES votes:      %5d", $vote_info->{invalid_tally}->{'YES'}));
		push(@body, sprintf("Number of invalid NO votes:       %5d", $vote_info->{invalid_tally}->{'NO'}));
		push(@body, sprintf("Number of invalid ABSTAIN votes:  %5d", $vote_info->{invalid_tally}->{'ABSTAIN'}));
	}

	push(@body, "");


	push(@body, format_para("For a vote to pass, YES votes must be at least $numer/$denomer of all valid (YES and NO) votes. There must also be at least $minyes more YES votes than NO votes. Abstentions, invalid votes and multiple votes do not affect the outcome. Anybody wishing to challenge the scoring must do so in aus.net.news."));
	push(@body, "");

	if ($pass && !$opt_recount) {
		push(@body, format_para("A five-day discussion period follows this announcement. If no serious allegations of voting irregularities or scoring mistakes are raised, ausadmin will issue the newgroup message shortly afterward."));

		push(@body, "");
	}

	push(@body, format_para("Votes marked as invalid or multi-votes were not counted in the result."));
	push(@body, "");

	my(@timel,$vts);
	@timel=localtime($ts_start);
	$vts = strftime("%Y-%m-%d %H:%M:%S %z", @timel);
	push(@body, "The voting period started at: $vts");
	@timel=localtime($ts_end);
	$vts = strftime("%Y-%m-%d %H:%M:%S %z", @timel);
	push(@body, "The voting period ended at:   $vts\n");


	push(@body, "\nVOTES RECEIVED:\n");
	foreach my $voter (sort by_domain_userid @{$vote_info->{voters}}) {
		$voter =~ s/\@/ at /;
		$voter =~ s/\./../g;
		push(@body, "  $voter");;
	}

	foreach my $l (@body) {
		print "$l\n";
	}
}

sub by_domain_userid {
	my($a1,$a2) = split("\@", lc($a));
	my($b1,$b2) = split("\@", lc($b));

	# make it empty string if it is undef
	$a1 ||= '';
	$a2 ||= '';
	$b1 ||= '';
	$b2 ||= '';

	$a2 cmp $b2 || $a1 cmp $b1;
}

sub setposts {
	my ($groupname,$filename,$firstpostdate,$interval,$count)=@_;

	local *POST;

	return if $debug;

	if (not open (POST,">>$vote_dir/$votename/$filename")) {
		die "Unable to mark group $votename as passed: $filename\n";
	}

	print POST "$groupname\t$firstpostdate\t$interval\t$count\n";
	close POST;
}

# Write a file called vote_result with a single line containing:
#    (PASS|FAIL) yes_valid_votes no_valid_votes abstain_valid_votes invalid_votes

sub write_vote_result {
	my $votename = shift;
	my $vote_info = shift;

	local *VR;

	my $path = "$vote_dir/$votename/vote_result";

	open(VR, ">$path") || die "Can't open $path for write: $!\n";

	printf VR "%s %d %d %d %d\n",
		$vote_info->{'vote_result'},
		$vote_info->{'valid_tally'}->{'YES'},
		$vote_info->{'valid_tally'}->{'NO'},
		$vote_info->{'valid_tally'}->{'ABSTAIN'},
		$vote_info->{'invalid_count'};

	close(VR);
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
		print "\n\n";
		print "No multiple votes were detected.\n";
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

