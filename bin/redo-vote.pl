#!/usr/bin/perl
#	@(#) redo-vote.pl - Get ready to run another vote on a newsgroup
#
#	Usage: cd ~ausadmin ; redo-vote.pl newsgroup-name

my $newsgroup = shift @ARGV;

die "No vote directory - cd?" if (!-d "vote");
die "No vote directory for $newsgroup" if (!-d "vote/$newsgroup");

# Check that there was a vote for this newsgroup, and that it finished
my $ng_dir = "vote/$newsgroup";

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
if (!mkdir($ng_dir, 0755)) {
	die "Unable to make $ng_dir: $!";
}

# Now copy relevant files from the old one...
system("cp -a $old_dir/charter $ng_dir/charter");
system("cp -a $old_dir/distribution $ng_dir/distribution");
system("cp -a $old_dir/ngline $ng_dir/ngline");
system("cp -a $old_dir/proposer $ng_dir/proposer");
system("cp -a $old_dir/rationale $ng_dir/rationale");

# That will do for the moment.

print "Good. Now run 'mkvote newsgroup-name' to setup the vote and\n";
print "post the CFV.\n";

exit(0);
