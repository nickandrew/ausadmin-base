#!/usr/bin/perl
#	gencheckgroups.pl

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
	print "gencheckgroups.pl: No list of newsgroups\n";
	exit(3);
}

$checkgroups_header = readfile("data/checkgroups.header");
$checkgroups_footer = readfile("data/checkgroups.footer");

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
# push(@body, $checkgroups_header);

push(@body, $checkgroups_footer);

if (!open(P, "|$pgpcmd")) {
	print "Unable to open pipe to pgp!\n";
	exit(7);
}

print P $checkgroups_header;

while (<C>) {
	print P $_;
}
close(C);

print P $checkgroups_footer;

close(P);

exit(0);
