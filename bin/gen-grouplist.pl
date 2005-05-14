#!/usr/bin/perl -w
#	@(#) $Id$
#	@(#) gen-grouplist.pl - Creates the "grouplist.signed" file.
#	Usage: gen-grouplist.pl [-d] [-h hier]
#	Option -d: debug mode, don't overwrite current ones, don't sign.
#

use strict;
use lib 'perllib';
use GroupList qw();
use GroupListMessage qw();
use Getopt::Std;

use vars qw($opt_d $opt_h);

getopts('dh:');


my $grouplist = 'grouplist';
my $signcmd = 'pgp-sign';
my $hier = $opt_h || Newsgroup::defaultHierarchy();
my $datadir = Newsgroup::datadir($hier);
my $grouplist_file = "$datadir/grouplist.signed";

my $gl = new GroupList(hier => $hier);
print "Writing to $datadir/grouplist\n";
$gl->write("grouplist.$$", "grouplist");


my $glm = new GroupListMessage(hier => $hier, signcmd => $signcmd);

$glm->write("grouplist.$$", $grouplist_file);

# Check it in
mkdir("$datadir/RCS", 0755);
system("ci -l -t- $datadir/grouplist < /dev/null");

exit(0);
