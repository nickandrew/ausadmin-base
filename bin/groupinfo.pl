#!/usr/bin/perl -w
#	@(#) groupinfo.pl - Find high and low article numbers in groups
#	$Header$
#
# groupinfo.pl groupname ...

use strict;

use Net::NNTP qw();
use Newsgroup qw();

my $newsserver = $ENV{NNTPSERVER} || 'news.zeta.org.au';

my $s = new Net::NNTP($newsserver, reader=>1);
if (!defined $s) {
	print "Unable to connect to news server, sorry!\n";
	exit(4);
}

my $rc = 0;

foreach my $group (@ARGV) {
	my($art_n,$art_low,$art_high,$name) = $s->group($group);

	if ($name eq '') {
		print "No such group: $group\n";
		$rc |= 2;
		next;
	}

	print "Ok: $group $art_n articles from $art_low to $art_high";

	my $g = new Newsgroup(name=>$group, nntp_server=>$s);
	my $flags = $g->group_flags();

	if ($flags eq 'm') {
		print " moderated\n";
	} elsif ($flags eq 'y') {
		print " unmoderated\n";
	} else {
		print " unknown group flags\n";
	}
}

$s->quit();

exit($rc);
