#!/usr/bin/perl
#	@(#) gen-initial-newsgroups.pl - Create newsgroup directories from "newsgroups" file
#
# $Id$
#
# Usage:	gen-initial-newsgroups.pl data/checkgroups

use lib 'bin';

use Newsgroup;

my $newsgroups_file = shift @ARGV || usage();

open(F, "<$newsgroups_file") or die "Unable to open $newsgroups_file for reading: $!";

while (<F>) {
	chomp;
	my($group,$description) = ($_ =~ /^(\S+)\s+(.+)/);

	if ($group eq '' || $description eq '') {
		print "Invalid line (ignored): $_\n";
		next;
	}

	my $ng = new Newsgroup(name => $group);
	$ng->create();
	$ng->set_attr('ngline', "$description\n");
}

close(F);

exit(0);

sub usage {
	die "Usage: gen-initial-newsgroups.pl data/checkgroups\n";
}
