#!/usr/bin/perl
#	@(#) gengrouplist.pl - Creates an informal list of newsgroups
#
# $Revision$
# $Date$

require "bin/postheader.pli";
require "bin/misc.pli";

$now = time;
$postaddress = "ausadmin\@aus.news-admin.org";
$grouplist = "data/ausgroups";

if (-f "/usr/bin/pgps") {
     $pgpcmd = "pgps -fat";
} else {
     $pgpcmd = "pgp -fast";
}

select(STDOUT); $| = 1;

if (! -f $grouplist) {
     die "gengrouplist.pl: No list of newsgroups: $grouplist\n";
}

$grouplist_header = readfile("data/grouplist.header");
$grouplist_footer = readfile("data/grouplist.footer");

($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = localtime(time);
$year += 1900; $mon++;
$now = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;

# Generate the message, header first

%header = (
	   'Subject' => "List of aus.* newsgroups at $now",
	   'Newsgroups' => 'aus.net.news'
	  );

# Open the groups file
if (!open(C, "<$grouplist")) {
     die "Unable to open $grouplist: $!\n";
}

print_header(\%header);

# Can't send this in @body because an extra blank line will be added
# push(@body, $grouplist_header);

push(@body, $grouplist_footer);

if (!open(P, "|$pgpcmd")) {
     die "Unable to open pipe to pgp!\n";
}

print P $grouplist_header;

while (<C>) {
     print P $_;
}
close(C);

print P $grouplist_footer;

close(P);

exit(0);

