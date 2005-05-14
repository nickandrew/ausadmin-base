#!/usr/bin/perl
#	@(#) gen-ausgroups.pl - Creates the "ausgroups" file and check it in
#
# $Source$
# $Revision$
# $Date$

use lib 'perllib';
use Getopt::Std qw(getopts);
use Ausadmin qw();
use Newsgroup qw();
use GroupList qw();

use vars qw($opt_h);

getopts('h:');

$opt_h ||= Newsgroup::defaultHierarchy();

die "No data subdirectory" if (!-d './data');

my $gl = new GroupList(hier => $opt_h);

$gl->write("checkgroups.$$", "checkgroups");

my $datadir = Newsgroup::datadir($opt_h);

# Check it in
system("ci -l -t- $datadir/checkgroups < /dev/null");

exit(0);
