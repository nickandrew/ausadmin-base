#!/usr/bin/perl
#	gengrouplist.pl

require "bin/postheader.pli";
require "bin/misc.pli";

$now = time;
$postaddress = "ausadmin\@aus.news-admin.org";
if (-f "/usr/bin/pgps") {
	$pgpcmd = "pgps -fat";
} else {
	$pgpcmd = "pgp -fast";
}

select(STDOUT); $| = 1;

if (!-f "data/ausgroups") {
	print "gengrouplist.pl: No list of newsgroups\n";
	exit(3);
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
if (!open(C, "<data/ausgroups")) {
	print "Unable to open data/ausgroups: $!\n";
	exit(3);
}

print_header(\%header);

# Can't send this in @body because an extra blank line will be added
# push(@body, $grouplist_header);

push(@body, $grouplist_footer);

if (!open(P, "|$pgpcmd")) {
	print "Unable to open pipe to pgp!\n";
	exit(7);
}

print P $grouplist_header;

while (<C>) {
	print P $_;
}
close(C);

print P $grouplist_footer;

close(P);

exit(0);
