#!/usr/bin/perl
#	@(#) mkcfv.pl: Create CFV message for a list of newsgroups
#	Usage: cd ~ausadmin ; bin/mkcfv.pl newsgroup-name ...
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
my $VoteAddress = 'vote@aus.news-admin.org';
my $BaseDir = './vote';

my $sign_it = 1;

die 'No vote subdirectory (must cd to ~ausadmin)' if (!-d $BaseDir);

if ($ARGV[0] eq '-u') {
	$sign_it = 0;
	shift @ARGV;
}

my @newsgroups = @ARGV;

# Now get proposer and distribution info
my $proposer = read_line("$BaseDir/$newsgroups[0]/proposer");
my $distribution = read_file("$BaseDir/$newsgroups[0]/distribution");
my $voterule = read_line("$BaseDir/$newsgroups[0]/voterule");

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

	eval {
		$g->{$newsgroup}->{cfv_notes} = read_file("$BaseDir/$newsgroup/cfv-notes.txt");
	};


	my $ConfigFile ="$BaseDir/$newsgroup/endtime.cfg";

	my $end_time = read_line($ConfigFile);

	# Now make the human-readable one

	$EndDate = gmtime($end_time - 1);
}

# Output the PGP-signed (or unsigned, if -u option given) cfv message to
# stdout.

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

my $cmd = "pgp -s -f";
if ($sign_it == 0) {
	$cmd = "cat";
}

if (!open(P, "|$cmd")) {
	print STDERR "Unable to open a pipe to PGP: $!";
	exit(3);
}

my @heading = ("CALL FOR VOTES");

foreach my $newsgroup (@newsgroups) {
	my $ng = "UnModerated newsgroup";
	if (defined $g->{$newsgroup}->{moderator}) {
		$ng = "Moderated newsgroup";
	}

	push(@heading, "$ng $newsgroup");
}

print P centred_text(@heading);
print P "\n";
print P "Newsgroups line(s)\n";

foreach my $newsgroup (@newsgroups) {
	my $r = $g->{$newsgroup};
	print P $r->{ngline}, "\n";

}

foreach my $newsgroup (@newsgroups) {
	if ($g->{$newsgroup}->{cfv_notes}) {
		print P "\nNOTE: $newsgroup\n";
		P->print(join("\n",@{$g->{$newsgroup}->{cfv_notes}}));
		print P "\n\n";
	}
}

my($numer, $denomer, $minyes) = split(/\s/, $voterule);

print P <<"EOMIDBODY";

PROPOSER: $proposer

Votes must be received by $EndDate

For this vote to pass, YES votes must be at least $numer/$denomer of all
valid (YES and NO) votes. There must also be at least $minyes more
YES votes than NO votes.

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

The ausadmin system will respond to your received message with a personal
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

=head1 @lines = centred_text(@lines)

Centre (assuming a width of 78 characters) the lines of text and return
the centred lines. Input lines can contain \n at the end; output lines
will be terminated with \n.

=cut

sub centred_text {
	my @output;
	my $width = 78;

	foreach my $line (@_) {
		chomp($line);
		if (length $line >= $width) {
			push(@output, "$line\n");
		} else {
			my $c = ($width - length $line)/2;
			push(@output, sprintf("%*s%s\n", $c, '', $line));
		}
	}

	return @output;
}


