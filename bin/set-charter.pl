#!/usr/bin/perl
#	@(#) set-charter.pl - Create or update a newsgroup charter
#
# $Id$
#
# Usage:	set-charter.pl newsgroup_name charter_file


use Ausadmin;
use Newsgroup;

my $group = shift @ARGV || usage();
my $charter_file = shift @ARGV || usage();

my $charter = Ausadmin::readfile($charter_file);
die "Empty charter or no charter file $charter_file" if (!defined $charter);

my $ng = new Newsgroup(name => $group);

$ng->set_attr('charter', $charter);

exit(0);

sub usage {
	die "Usage: set-charter.pl newsgroup_name charter_file\n";
}
