#!/usr/bin/perl
#	@(#) gengrouplist.pl - Creates an informal list of newsgroups
#
# $Source$
# $Revision$
# $Date$

require "bin/postheader.pli";
require "bin/misc.pli";

my $postaddress = "ausadmin\@aus.news-admin.org";
my $grouplist = "data/ausgroups";

if (! -f $grouplist) {
	die "gengrouplist.pl: No list of newsgroups: $grouplist\n";
}

my $grouplist_header = readfile("data/grouplist.header");
my $grouplist_footer = readfile("data/grouplist.footer");

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = localtime(time);
$year += 1900; $mon++;
my $ts = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;

# Generate the message, header first

my %header = (
	   'Subject' => "List of aus.* newsgroups at $ts",
	   'Newsgroups' => 'aus.net.news'
	  );

# Open the groups file
if (!open(C, "<$grouplist")) {
	die "Unable to open $grouplist: $!\n";
}

print_header(\%header);

# Can't send this in @body because an extra blank line will be added
# push(@body, $grouplist_header);

# push(@body, $grouplist_footer);

print $grouplist_header;

while (<C>) {
	print $_;
}
close(C);

print $grouplist_footer;

exit(0);

