#!/usr/bin/perl
#	@(#) make-rfd.pl - Create an RFD from its component pieces
#
# $Source$
# $Revision$
# $Date$

=head1 NAME

make-rfd.pl - Create an RFD from its component pieces

=head1 SYNOPSIS

make-rfd.pl newsgroup-name

=head1 DESCRIPTION

This program concatenates the various control files in a newsgroup's
directory to create an RFD for that newsgroup. Used mostly to recreate
the RFDs for very old newsgroups.

The following files from the B<vote/$newsgroup> directory are used:

B<ngline>,
B<rationale>,
B<charter>,
B<proposer>,
B<distribution>,

Also the following template files from the B<config> directory are used:

B<rfd-head.txt>,
B<rfd-procedure.txt>

=cut

use lib '.', 'bin';
use Ausadmin;

my $newsgroup = shift @ARGV;

if (!-d "vote/$newsgroup") {
	die "No vote/$newsgroup directory - cd?";
}

my $d="vote/$newsgroup";

foreach my $i (qw/ngline rationale charter proposer distribution/) {
	if (!-f "$d/$i") {
		die "No $d/$i";
	}
}

my $ngline = Ausadmin::read1line("$d/ngline");
my $rationale = Ausadmin::readfile("$d/rationale");
my $charter = Ausadmin::readfile("$d/charter");
my $proposer = Ausadmin::read1line("$d/proposer");
my $distribution = Ausadmin::readfile("$d/distribution");

# Now read the template
my $procedure = Ausadmin::readfile("config/rfd-procedure.txt");

# Now put it all together
my @lines;

push(@lines, "REQUEST FOR DISCUSSION");
push(@lines, "Unmoderated newsgroup $newsgroup");
@lines = Ausadmin::centred_text(@lines);	# yuk
push(@lines, "\n");

my $x = <<EOF;
This is a formal Request For Discussion (RFD) for the creation of
an Australian USENET Newsgroup (unmoderated) $newsgroup. This is
not a Call For Votes (CFV); you cannot vote at this time.
EOF

# Now format the paragraph
my @fmt = Ausadmin::format_para($x);
push(@lines, join("\n", @fmt), "\n");

push(@lines, "\nNewsgroup line:\n", "$ngline\n\n");

# print "x is $x[0] then $x[1] then $x[2].\n";

push(@lines, "RATIONALE: $newsgroup\n\n", $rationale);
push(@lines, "\nEND RATIONALE.\n\n");

push(@lines, "CHARTER: $newsgroup\n\n", $charter);
push(@lines, "\nEND CHARTER.\n\n");

push(@lines, "PROPOSER: $proposer\n\n");

push(@lines, "PROCEDURE:\n\n", $procedure, "\n");

push(@lines, "DISTRIBUTION: $newsgroup\n\n", $distribution);

# Print first, the message header ...

my %header = (
	Subject => "Request For Discussion (RFD): $newsgroup",
	Newsgroups => join(',', split("\n", $distribution))
);

Ausadmin::print_header(\%header);

foreach (@lines) {
	print $_;
}

exit(0);
