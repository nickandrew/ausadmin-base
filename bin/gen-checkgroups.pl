#!/usr/bin/perl
#	@(#) gen-checkgroups.pl - Creates the "checkgroups.msg" file.
#	Usage: gen-checkgroups.pl [-d]
#	Option -d: debug mode, don't overwrite current ones, don't sign.
#
# $Source$
# $Revision$
# $Date$

use lib 'bin';
use Checkgroups;
use Getopt::Std;

use vars qw($opt_d);

getopts('d');


my $grouplist = "data/ausgroups";
my $signcmd = $opt_d ? '/bin/cat' : 'signcontrol';
my $checkgroups_file = $opt_d ? 'checkgroups.msg' : 'data/checkgroups.msg';


my $gl = new Checkgroups(signcmd => $signcmd, grouplist_file => $grouplist);

$gl->write("checkgroups.$$", $checkgroups_file);

# Check it in
system("ci -l -t- $checkgroups_file < /dev/null");

exit(0);
