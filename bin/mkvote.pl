#!/usr/bin/perl
#	@(#) mkvote.pl - Create directory for a new vote
#
# $Source$
# $Revision$
# $Date$

# Commonly used variables

die "This program is obsolete -- see bin/mkvote -- nick";

$HomeDir="/virt/web/ausadmin";
$BaseDir="$HomeDir/vote";

if (not @ARGV) {
	die "Usage: $0 RFD\n";
}

@RFD=<>;

@newsgrouplines=grep {/^newsgroup line:/i../^$|^RATIONALE:/i} @RFD;

@groups=grep {s/^(aus\.[^\s]+)/$1/} @newsgrouplines;

open RFD,">$HomeDir/tmp/info.$$" or die "Unable to open info.$$ because $!\n";

print RFD @groups;

close RFD;

foreach my $Newsgroup (@groups) {

	gendirs("$BaseDir/$Newsgroup", "$BaseDir/$Newsgroup/conf", "$BaseDir/$Newsgroup/votes");

	system ("echo \"2 3 10\" > $Newsgroup/voterule");
	system ("echo \"14\" > $Newsgroup/voteperiod");
	system ("echo \`date +\%s\` > $Newsgroup/posted.cfg");

	open (CFV,"|mkcfv.pl > $Newsgroup/posted.cfv 2>$HomeDir/tmp/pgp.$$") or die "mkvote.pl unable to fork for Call For Votes $!\n";

	print CFV @RFD;

	close CFV or die "Unable to make Call For Votes $!\n";

	unlink "$HomeDir/CFV/$Newsgroup";
	symlink "$BaseDir/$Newsgroup/posted.cfv","$HomeDir/CFV/$Newsgroup";
}

print "mkvote.pl done at `date`\n";
exit(0);

# make directories if they don't already exist
sub gendirs {
	foreach my $dir (@_) {
		if (! -d $dir) {
			mkdir($dir,0755);
		}
	}
}
