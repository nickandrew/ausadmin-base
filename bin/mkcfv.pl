#!/usr/bin/perl
#	@(#) mkcfv.pl: Create CFV message for a list of newsgroups
#
# $Source$
# $Revision$
# $Date$
#
# Makes the Call For Votes post from a template and the group charter
# and outputs to STDOUT (after signing through pgp).

use Time::Local;
use IO::Handle;

# Info Needed to run the script
my $VoteAddress = "vote\@aus.news-admin.org";
my $BaseDir = "./vote";
my $default_voteperiod = 21;		# days

my $VotePeriod = $default_voteperiod;

die "No vote subdirectory (must cd to ~ausadmin)" if (!-d $BaseDir);

my @newsgroups = @ARGV;

# Now get proposer and distribution info
my $proposer = read_line("$BaseDir/$newsgroups[0]/proposer");
my $distribution = read_file("$BaseDir/$newsgroups[0]/distribution");

die "No proposer" if (!defined $proposer);
die "No distribution" if (!@$distribution);

# Store all the group info in $g
my $g = { };

foreach my $newsgroup (@newsgroups) {
	

	$g->{$newsgroup}->{ngline} = read_line("$BaseDir/$newsgroup/ngline");
	$g->{$newsgroup}->{rationale} = read_file("$BaseDir/$newsgroup/rationale");
	$g->{$newsgroup}->{charter} = read_file("$BaseDir/$newsgroup/charter");
	eval {
		$g->{$newsgroup}->{modinfo} = read_file("$BaseDir/$newsgroup/modinfo");
		$g->{$newsgroup}->{moderator} = read_file("$BaseDir/$newsgroup/moderator");
	};

	my $ConfigFile ="$BaseDir/$newsgroup/endtime.cfg";

	my $end_time = read_file($ConfigFile);

	# Now make the human-readable one

	$EndDate = gmtime($end_time);
}

# Opens the template Call For Votes file and constructs the actual CFV file
# which is output to STDOUT
select(STDOUT);
$| = 1;


my $subject = "CFV: @newsgroups";
my $dist = join(',', @$distribution);

print <<"EOHEADERS";
Subject: $subject
From: $VoteAddress
Newsgroups: $dist
Followup-to: none

EOHEADERS

if (!open(P, "|pgp -s -f")) {
	print STDERR "Unable to open a pipe to PGP: $!";
	exit(3);
}

print P <<"EOTOPBODY";
                           CALL FOR VOTES
EOTOPBODY

foreach my $newsgroup (@newsgroups) {
	my $ng = "UnModerated newsgroup";
	if (defined $g->{$newsgroup}->{moderator}) {
		$ng = "Moderated newsgroup";
	}

	print P "\t\t\t\t$ng $newsgroup\n";
}

print P "\n";
print P "Newsgroups line(s)\n";

foreach my $newsgroup (@newsgroups) {
	my $r = $g->{$newsgroup};
	print P $r->{ngline}, "\n";

}

print P <<"EOMIDBODY";

PROPOSER: $proposer

Votes must be received by $EndDate

This vote is being conducted by ausadmin. For voting questions contact
ausadmin\@aus.news-admin.org. For questions about the proposed group contact
$proposer.

EOMIDBODY

foreach my $newsgroup (@newsgroups) {
	my $r = $g->{$newsgroup};

	P->print("RATIONALE: $newsgroup\n\n");
	P->print(join("\n",@{$r->{rationale}}));
	print P "\nEND RATIONALE.\n\n";

	P->print("CHARTER: $newsgroup\n\n");
	P->print(join("\n",@{$r->{charter}}));
	print P "\nEND CHARTER.\n\n";
}

print P <<"EOMEND";
HOW TO VOTE

To vote, you must send an e-mail message to: $VoteAddress.
The subject of your e-mail message is not important.

Your mail message should contain only one of the following statements:
      I vote YES on aus.example.name
      I vote NO on aus.example.name

You must replace aus.example.name with the name of the newsgroup that you are
voting for. If the poll is for multiple newsgroups you should include one vote
for each newsgroup, e.g.

I vote YES on aus.example.name
I vote NO on aus.silly.group
I vote YES on aus.good.group

Anything else may be rejected by the automatic vote counting program.

The ausadmin system will respond to your received ballots with a personal
acknowledgement by E-mail so you must send from your real e-mail address,
not a spam-block address. If you do not receive an acknowledgement within
24 hours, try again. It is your responsibility to make sure your vote is
registered correctly.

Only one vote per person, no more than one vote per E-mail address.
Votes from invalid or unreachable email addresses may be rejected.
Multiple voting attempts will be ignored. E-mail addresses of all
voters will be published in the final voting results list.


[ Note: CFVs and control messages will be signed with the ausadmin key.
  Download it from http://aus.news-admin.org/ausadmin.asc now!   --nick ]

EOMEND


close(P);

# All done

exit(0);

sub read_line {
	my $f = shift;
	local *X;
	open(X, "<$f") or die "Unable to open $f: $!";
	my $v = <X>;
	chomp($v);
	close(X);
	return $v;
}

sub read_file {
	my $f = shift;
	local *X;
	open(X, "<$f") or die "Unable to open $f: $!";
	my @v = <X>;
	chomp(@v);
	close(X);
	return \@v;
}

