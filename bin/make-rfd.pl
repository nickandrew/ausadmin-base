#!/usr/bin/perl
#	@(#) make-rfd.pl - Create an RFD message for a proposal
#
# $Source$
# $Revision$
# $Date$

=head1 NAME

make-rfd.pl - Create an RFD message for a proposal

=head1 SYNOPSIS

make-rfd.pl [B<-r>] proposal

=head1 DESCRIPTION

This program concatenates the various control files in a proposal's
directory to create an RFD for that proposal. Used to create an RFD
ready-for-posting.

The following files from the B<vote/$proposal> directory are used:

 B<change>
 B<charter:$newsgroup>
 B<distribution>
 B<modinfo:$newsgroup>
 B<ngline:$newsgroup>
 B<proposer>
 B<rationale>

Also the following template files from the B<config> directory are used:

 B<rfd-procedure.txt>

=head1 OPTIONS

B<-r> indicates that this is a REVISED RFD, and the language changes
a bit to cater for that. Not implemented yet!

=cut

use Getopt::Std;
use lib './bin';
use Ausadmin;

my %opts;

getopts('r', \%opts);

my $proposal = shift @ARGV;

my $d="vote/$proposal";

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
my $proposer = Ausadmin::read1line("$d/proposer");
my $distribution = Ausadmin::readfile("$d/distribution");
my $rfd_notes = Ausadmin::readfile("$d/rfd-notes.txt");

my $per_newsgroup = { };

# Do this just for one newsgroup at the moment!
foreach my $newsgroup ($change->{'newsgroup'}) {
	$per_newsgroup->{$newsgroup}->{ngline} = Ausadmin::read1line("$d/ngline:$newsgroup");
	$per_newsgroup->{$newsgroup}->{charter} = Ausadmin::readfile("$d/charter:$newsgroup");
	$per_newsgroup->{$newsgroup}->{modinfo} = Ausadmin::readfile("$d/modinfo:$newsgroup");
}

# Now read the template
my $procedure = Ausadmin::readfile("config/rfd-procedure.txt");

# Now put it all together
my @lines;

push(@lines, "REQUEST FOR DISCUSSION");

# Now key on which kind of change it is ... KLUDGE (only one change here)
my $change_descr;
my $change_type = $change->{'type'};
my $newsgroup = $change->{'newsgroup'};

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

my $x = <<EOF;
This is a formal Request For Discussion (RFD) for
$change_descr.
This is not a Call For Votes (CFV); you cannot vote at this time.
EOF

# Now format the paragraph
my @fmt = Ausadmin::format_para($x);
push(@lines, join("\n", @fmt), "\n\n");

if ($change_type =~ /^(newgroup|moderate)$/) {
	push(@lines, "Newsgroup line:\n");
	# Now one line for each newsgroup considered
	foreach my $newsgroup (sort (keys %$per_newsgroup)) {
		push(@lines, $per_newsgroup->{$newsgroup}->{ngline} . "\n");
	}
	push(@lines, "\n");
}

if ($rfd_notes) {
	push(@lines, "RFD NOTES:\n\n", $rfd_notes);
	push(@lines, "\nEND RFD NOTES.\n\n");
}

push(@lines, "RATIONALE:\n\n", $rationale);
push(@lines, "\nEND RATIONALE.\n\n");

# Now we loop through, emitting all the per-newsgroup information we have
foreach my $newsgroup (sort (keys %$per_newsgroup)) {
	if (exists $per_newsgroup->{$newsgroup}->{charter}) {
		push(@lines, "CHARTER: $newsgroup\n\n", $per_newsgroup->{$newsgroup}->{charter});
		push(@lines, "\nEND CHARTER.\n\n");
	}

	# Do the same thing for mod_status (probably not required)
#	if (exists $per_newsgroup->{$newsgroup}->{modinfo}) {
#		push(@lines, "MODERATOR INFO: $newsgroup\n\n", $modinfo);
#		push(@lines, "\nEND MODERATOR INFO.\n\n");
#		push(@lines, "SUBMISSION EMAIL: $change->{'submission_email'}\n");
#		push(@lines, "REQUEST EMAIL: $change->{'request_email'}\n");
#		push(@lines, "\n");
#	}
}

push(@lines, "PROPOSER: $proposer\n\n");

push(@lines, "PROCEDURE:\n\n", $procedure, "\n");

push(@lines, "DISTRIBUTION:\n\n", $distribution);

# Print first, the message header ...

my %header = (
	Subject => "Request For Discussion (RFD): $newsgroup",
	Newsgroups => join(',', split("\n", $distribution))
);

if ($opts{'r'}) {
	$header{Subject} = "REVISED " . $header{Subject};
}

Ausadmin::print_header(\%header);

foreach (@lines) {
	print $_;
}

exit(0);
