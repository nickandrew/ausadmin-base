#!/usr/bin/perl
#	gencheckgroups.pl

# $Revision$
# $Date$

require "bin/postheader.pli";
require "bin/misc.pli";

$now = time;
$signcmd = "bin/signcontrol";

select(STDOUT); $| = 1;

if (!-f "data/ausgroups") {
	die "gencheckgroups.pl: No list of newsgroups\n";
}

$checkgroups_header = readfile("data/checkgroups.header");
$checkgroups_footer = readfile("data/checkgroups.footer");

($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = localtime(time);

$monthname=("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[$mon];

$year += 1900; $mon++;
$now = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;


# Generate the message, header first

%header = (
	'From' => '<ausadmin@aus.news-admin.org>',
	'Subject' => 'checkgroups',
	'Newsgroups' => 'aus.net.news',
	'Control' => 'checkgroups',
	'Approved' => 'ausadmin@aus.news-admin.org',
	'Followup-To' => '',
	'X-PGPKey' => '',
	'Organization' => '',
	'Path' => 'aus.news-admin.org|ausadmin',
	'Message-id' => "$^T$$ausadmin\@aus.news-admin.org",
        'Date' => "$mday $monthname $year $hour:$min:$sec",
);

# Open the groups file
if (!open(C, "<data/ausgroups")) {
	die "Unable to open data/ausgroups: $!\n";
}

if (!open(P, "|$signcmd")) {
	die "Unable to open pipe to signcontrol!\n";
}

select(P);
print_header(\%header);

print P $checkgroups_header;
print P "\n";

while (<C>) {
	print P $_;
}
close(C);

print P $checkgroups_footer;

close(P);

exit(0);
