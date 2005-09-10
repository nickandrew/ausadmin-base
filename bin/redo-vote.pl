#!/usr/bin/perl
#	@(#) redo-vote.pl - Get ready to run another vote on a newsgroup
#
#	Usage: cd ~ausadmin ; redo-vote.pl newsgroup-name

=head1 NAME

redo-vote.pl - Get ready to run another vote on a newsgroup

=head1 SYNOPSIS

cd ~ausadmin ; redo-vote.pl newsgroup-name

=head1 DESCRIPTION

This program is used to start a new discussion on a newsgroup
which was previously voted-on.

It expects to find a completed vote (passed or failed) in
the vote/$newsgroup directory. This directory is then renamed to
vote/$newsgroup:yyyy-mm-dd where yyyy-mm-dd is the date of the
start of the vote.

In theory a newsgroup could be discussed only (RFD) with no vote
and then abandoned, and another RFD resubmitted later with the
same name. This program doesn't cater for that, yet.

=cut

use Newsgroup;

my $newsgroup = shift @ARGV || usage();

die "Invalid newsgroup: $newsgroup" if (!Newsgroup::validate($newsgroup));

my $ng_dir = "vote/$newsgroup";

die "redo-vote.pl: No directory $ng_dir" if (!-d "vote/$newsgroup");

# Check that there was a vote for this newsgroup, and that it finished

die "Never voted on $newsgroup" if (!-f "$ng_dir/endtime.cfg");
die "Never voted on $newsgroup" if (!-f "$ng_dir/vote_start.cfg");

# Make sure the vote ended
open(F, "<$ng_dir/endtime.cfg");
my $end_time = <F>;
chomp $end_time;
close(F);

if (time() < $end_time) {
	die "Vote for $newsgroup still running!";
}

open(G, "<$ng_dir/vote_start.cfg");
my $start_time = <G>;
chomp $start_time;
close(G);

# Now rename the directory
my($sec,$min,$hour,$mday,$mon,$year) = localtime($start_time);
$mon++; $year += 1900;
my $yyyymmdd = sprintf "%d-%02d-%02d", $year, $mon, $mday;

my $old_dir = "vote/$newsgroup:$yyyymmdd";
if (-d $old_dir) {
	die "Old directory vote/$newsgroup:$yyyymmdd already exists!";
}

rename($ng_dir, $old_dir);

# That will do for the moment.

print "$ng_dir directory renamed to $old_dir.\n";
print "Now run 'new-rfd newsgroup-name rfd-file' to setup the new vote.\n";

exit(0);

sub usage {
	die "Usage: redo-vote.pl newsgroup-name";
}
