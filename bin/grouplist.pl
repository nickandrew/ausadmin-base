#!/usr/bin/perl
#	@(#) grouplist.pl - Suck down the server's active file (basically)
#
# grouplist.pl

use Net::NNTP;

my $newsserver = $ENV{NNTPSERVER} || 'news.zeta.org.au';

my $s = new Net::NNTP($newsserver, reader=>1);
if (!defined $s) {
	print "Unable to connect to news server, sorry!\n";
	exit(4);
}

my $groups_hr = $s->list();

$s->quit();

foreach my $group (sort (keys %$groups_hr)) {
	my $l = $groups_hr->{$group};
	# groupname first last flags
	print $group, ' ', $l->[1], ' ', $l->[0], ' ', $l->[2], "\n";
}

exit(0);
