#!/usr/bin/perl
#	@(#) mkcfv.pl: Create a CFV message for a proposal
#	Usage: cd ~ausadmin ; bin/mkcfv.pl newsgroup-name
#
# $Source$
# $Revision$
# $Date$
#
# Makes the Call For Votes post from a template and the group charter
# and outputs to STDOUT (after signing through pgp).

=head1 NAME

mkcfv.pl - Create a CFV message for a list of newsgroups (really only one atm)

=head1 SYNOPSIS

 cd ~ausadmin ; mkcfv.pl newsgroup > tmp/cfv-unsigned.$newsgroup
 bin/pgp-sign < tmp/cfv-unsigned.$newsgroup > vote/$newsgroup/posted.cfv
 bin/post.pl < vote/$newsgroup/posted.cfv

=head1 DESCRIPTION

This program creates a CFV message for a proposal from the various control
files in a newsgroup's directory. The CFV message is written to standard
output, and you have to sign it before posting.

The following files from the B<vote/$newsgroup> directory are used:

B<change>,
B<charter>,
B<distribution>,
B<modinfo>,
B<ngline>,
B<proposer>,
B<rationale>,

Also the following template files from the B<config> directory are used:

B<cfv-procedure.txt>

=cut

use POSIX qw(:time_h);
use Time::Local;
use IO::Handle;

use lib 'bin';
use Ausadmin;

# Info Needed to run the script
my $VoteAddress = 'vote@aus.news-admin.org';
my $BaseDir = './vote';


die 'No vote subdirectory (must cd to ~ausadmin)' if (!-d $BaseDir);

my $newsgroup = shift @ARGV;

my $d="vote/$newsgroup";

if (!-d $d) {
	die "No $d directory - cd?";
}

foreach my $i (qw/change rationale proposer distribution/) {
	if (!-f "$d/$i") {
		die "No $d/$i";
	}
}

# KLUDGE ... This assumes only one change per proposal
my $change = Ausadmin::read_keyed_file("$d/change");

my $rationale = Ausadmin::readfile("$d/rationale");
my $modinfo = Ausadmin::readfile("$d/modinfo");
my $proposer = Ausadmin::read1line("$d/proposer");
my $distribution = Ausadmin::readfile("$d/distribution");

# This is per-change
my $ngline = Ausadmin::read1line("$d/ngline:$newsgroup");
my $charter = Ausadmin::readfile("$d/charter:$newsgroup");

# Now get voting-specific info
my $voterule = Ausadmin::read1line("$d/voterule");
my $cfv_notes = Ausadmin::readfile("$d/cfv-notes.txt");
my $end_time = Ausadmin::readfile("$d/endtime.cfg");
# Now make the human-readable one
my @end_tm = localtime($end_time - 1);
my $EndDate = strftime("%A %B %d %Y %H:%M:%S %z", @end_tm);

# Now read the template
my $procedure = Ausadmin::readfile("config/cfv-procedure.txt");

die "No proposer" if (!defined $proposer);
die "No distribution" if (!defined $distribution);

# $g->{$newsgroup}->{moderator} = Ausadmin::readfile("$BaseDir/$newsgroup/moderator");

# Now put it all together
my @lines;

push(@lines, "CALL FOR VOTES");

# Now key on which kind of change it is ...
my $change_descr;
my $change_type = $change->{'type'};

if ($change_type eq 'newgroup') {
	if ($change->{'mod_status'} eq 'm') {
		push(@lines, "Creation of Moderated newsgroup $newsgroup");
		$change_descr = "the creation of a new Australian moderated newsgroup $newsgroup";
	} else {
		push(@lines, "Creation of Unmoderated newsgroup $newsgroup");
		$change_descr = "the creation of a new Australian unmoderated newsgroup $newsgroup";
	}
} elsif ($change_type eq 'rmgroup') {
	push(@lines, "Remove newsgroup $newsgroup");
	$change_descr = "the removal of the existing newsgroup $newsgroup";
} elsif ($change_type eq 'moderate') {
	push(@lines, "Change $newsgroup to moderated");
	$change_descr = "the change of $newsgroup to moderated";
} elsif ($change_type eq 'unmoderate') {
	push(@lines, "Change $newsgroup to unmoderated");
	$change_descr = "the change of $newsgroup to unmoderated";
} elsif ($change_type eq 'charter') {
	push(@lines, "Change charter of $newsgroup");
	$change_descr = "changing the charter of $newsgroup";
} else {
	die "Unknown change type $change_type";
}


@lines = Ausadmin::centred_text(@lines);	# yuk
push(@lines, "\n");

# Here comes the introductory paragraph
my $x = <<EOF;
This is a formal Call For Votes (CFV) for
$change_descr.
Please see below for voting instructions.
EOF

if ($cfv_notes ne '') {
	push(@lines, "CFV NOTES:\n\n", $cfv_notes);
	push(@lines, "\nEND CFV NOTES.\n\n");
}

# Now format the paragraph
my @fmt = Ausadmin::format_para($x);
push(@lines, join("\n", @fmt), "\n\n");


if ($change_type =~ /^(newgroup|moderate)$/) {
	push(@lines, "Newsgroups line:\n", "$ngline\n\n");
}

my($numer, $denomer, $minyes) = split(/\s/, $voterule);

$x = <<EOF;
Votes must be received by $EndDate.

For this vote to pass, YES votes must be at least $numer/$denomer of all
valid (YES and NO) votes. There must also be at least $minyes more
YES votes than NO votes.

This vote is being conducted by ausadmin. For voting questions contact
ausadmin\@aus.news-admin.org. For questions about the proposed group
contact $proposer.

EOF

push(@lines, $x);

push(@lines, "RATIONALE:\n\n", $rationale);
push(@lines, "\nEND RATIONALE.\n\n");

if ($change_type =~ /^(newgroup|moderate|charter|unmoderate)$/) {
	push(@lines, "CHARTER: $newsgroup\n\n", $charter);
	push(@lines, "\nEND CHARTER.\n\n");
}

if ($change->{mod_status} eq 'm') {
	# Need to add the moderation information
	push(@lines, "MODERATOR INFO: $newsgroup\n\n", $modinfo);
	push(@lines, "\nEND MODERATOR INFO.\n\n");
	push(@lines, "SUBMISSION EMAIL: $change->{'submission_email'}\n");
	push(@lines, "REQUEST EMAIL: $change->{'request_email'}\n");
	push(@lines, "\n");
}

push(@lines, "PROPOSER: $proposer\n\n");

push(@lines, "HOW TO VOTE:\n\n", $procedure, "\n");

# CFVs have no distribution section
# push(@lines, "DISTRIBUTION:\n\n", $distribution);

# Print first, the message header ...

my %header = (
	From => 'Vote-taker <vote@aus.news-admin.org>',
	'Followup-To' => 'aus.net.news',
	Subject => "Call For Votes (CFV): $newsgroup",
	Newsgroups => join(',', split("\n", $distribution))
);

Ausadmin::print_header(\%header);

foreach (@lines) {
	print $_;
}

exit(0);

# end of mkcfv.pl
