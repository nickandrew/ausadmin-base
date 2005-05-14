#!/usr/bin/perl
#	@(#) gen-initial-newsgroups.pl - Create newsgroup directories from "newsgroups" file
#
# $Id$
#
# Usage:	gen-initial-newsgroups.pl [-h hierarchy] data/checkgroups

use lib 'perllib';

use Getopt::Std qw(getopts);
use Newsgroup qw();

use vars qw($opt_h);
getopts('h:');

$opt_h ||= Newsgroup::defaultHierarchy();

my $newsgroups_file = shift @ARGV || usage();

open(F, "<$newsgroups_file") or die "Unable to open $newsgroups_file for reading: $!";

while (<F>) {
	chomp;
	my($group,$description) = ($_ =~ /^(\S+)\s+(.+)/);

	if ($group eq '' || $description eq '') {
		print "Invalid line (ignored): $_\n";
		next;
	}

	my $ng = new Newsgroup(name => $group, hier => $opt_h);
	$ng->create();
	$ng->set_attr('ngline', "$description\n");
}

close(F);

exit(0);

sub usage {
	die "Usage: gen-initial-newsgroups.pl [-h hierarchy] data/checkgroups\n";
}
