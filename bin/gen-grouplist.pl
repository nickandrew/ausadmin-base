#!/usr/bin/perl -w
#	@(#) $Id$
#	@(#) gen-grouplist.pl - Creates the "grouplist.signed" file.
#	Usage: gen-grouplist.pl [-d]
#	Option -d: debug mode, don't overwrite current ones, don't sign.
#

use strict;
use lib 'bin';
use GroupListMessage;
use Getopt::Std;

use vars qw($opt_d);

getopts('d');


my $grouplist = "data/ausgroups";
my $signcmd = $opt_d ? '/bin/cat' : 'pgp-sign';
my $grouplist_file = $opt_d ? 'data/grouplist' : 'data/grouplist.signed';


my $gl = new GroupListMessage(signcmd => $signcmd, grouplist_file => $grouplist);

$gl->write("grouplist.$$", $grouplist_file);

# Check it in
system("ci -l -t- $grouplist_file < /dev/null");

exit(0);
