#!/usr/bin/perl
#	@(#) gen-checkgroups.pl - Creates the "checkgroups.signed" file.
#	$Header$
#
#	Usage: gen-checkgroups.pl [-d] [-h hierarchy]
#	Option -d: debug mode, don't overwrite current ones, don't sign.
#

use lib 'bin';
use Newsgroup qw();
use Checkgroups qw();
use Getopt::Std;

use vars qw($opt_d $opt_h);

getopts('dh:');

my $datadir = $opt_h ? "$opt_h.data" : 'data';

my @newsgroup_list = Newsgroup::list_newsgroups(datadir => $datadir);

if (!@newsgroup_list) {
	die "No groups in $datadir\n";
}

my $s = '';

foreach my $name (sort @newsgroup_list) {
	my $ng = new Newsgroup(name => $name, datadir => $datadir);
	my $string = $ng->get_attr('ngline');
	$s .= sprintf "%s\t%s", $name, $string;
}

my $grouplist = "$datadir/checkgroups";
my $signcmd = 'signcontrol';
my $checkgroups_file = "$datadir/checkgroups.signed";

open(GL, ">$grouplist") || die "Unable to open $grouplist for write: $!";
print GL $s;
close(GL);

if (! $opt_d) {
	my $gl = new Checkgroups(signcmd => $signcmd, grouplist_file => $grouplist);
	$gl->write("checkgroups.$$", $checkgroups_file);

	# Check it in
	system("ci -l -t- $checkgroups_file < /dev/null");
}

exit(0);
