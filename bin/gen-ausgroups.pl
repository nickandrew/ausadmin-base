#!/usr/bin/perl
#	@(#) gen-ausgroups.pl - Creates the "ausgroups" file and check it in
#
# $Source$
# $Revision$
# $Date$

use lib 'bin';
use Ausadmin;
use GroupList;

my $grouplist_file = "data/checkgroups";

die "No data subdirectory" if (!-d './data');

my $gl = new GroupList();

$gl->write("checkgroups.$$", $grouplist_file);

# Check it in
system("ci -l -t- $grouplist_file < /dev/null");

exit(0);
