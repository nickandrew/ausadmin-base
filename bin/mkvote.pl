#!/usr/bin/perl -w
#
# $Source$
# $Revision$
# $Date$

# Commonly used variables

$HomeDir="/virt/web/ausadmin";
$BaseDir="$HomeDir/vote";

if (not @ARGV) {
  die "Usage: $0 RFD\n";
}

@RFD=<>;

@newsgrouplines=grep {/^newsgrougroup line:/i../^$|^RATIONALE:/i} @RFD;

@groups=grep {s/^(aus\.[^\s]+)/$1/} @newsgrouplines;

open RFD,">$HomeDir/tmp/info.$$" or die "Unable to open info.$$ because $!\n";

print RFD @groups;

close RFD;

gendirs("$BaseDir/$Newsgroup","$BaseDir/$Newsgroup/conf",
	"$BaseDir/$Newsgroup/votes");

system ("echo \"2 3 10\" > $Newsgroup/voterule");
system ("echo \"14\" > $Newsgroup/voteperiod");
system ("echo \`date +\%s\` > $Newsgroup/posted.cfg");

open (CFV,"|mkcfv.pl > $Newsgroup/posted.cfv 2>$HomeDir/tmp/pgp.$$") or die "Unable to fork for Call For Votes $!\n";

print CFV @RFD;

close CFV or die "Unable to make Call For Votes $!\n";

unlink "$HomeDir/CFV/$Newsgroup";
symlink "$BaseDir/$Newsgroup/posted.cfv","$HomeDir/CFV/$Newsgroup";

print "Done at `date`\n";

# make directories if they don't already exist
sub gendirs 
{
  for $dir (@_) {
    if (not -d $dir) {
      mkdir $dir,'0777';
    }
  }
}
