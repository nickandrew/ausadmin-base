#!/usr/bin/perl
#	@(#) gencheckgroups.pl - Generate a checkgroups message
#
# $Source$
# $Revision$
# $Date$

use lib 'bin';

use Ausadmin;
use Newsgroup;

my $signcmd = "bin/signcontrol";
my $head_text = Ausadmin::readfile("data/checkgroups.header");
my $foot_text = Ausadmin::readfile("data/checkgroups.footer");

select(STDOUT); $| = 1;

my($sec,$min,$hour,$mday,$mon,$year,$wday,$isdst) = localtime(time());

my $monthname=("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[$mon];

$year += 1900; $mon++;
my $now = sprintf "%d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec;


# Generate the message, header first

my %header = (
	'From' => '<ausadmin@aus.news-admin.org>',
	'Subject' => 'checkgroups',
	'Newsgroups' => 'aus.net.news',
	'Control' => 'checkgroups',
	'Approved' => 'ausadmin@aus.news-admin.org',
	'Followup-To' => '',
	'X-PGPKey' => '',
	'Organization' => '',
	'Path' => 'aus.news-admin.org|ausadmin',
#	Note: Message-ID is added automatically by bin/signcontrol
#	'Message-ID' => "$^T$$ausadmin\@aus.news-admin.org",
        'Date' => "$mday $monthname $year $hour:$min:$sec",
);

# Get a list of all newsgroups which are supposed to exist right now
my @group_list = Newsgroup::list_newsgroups();

if (!open(P, "|$signcmd")) {
	die "Unable to open pipe to $signcmd!\n";
}

select(P);
Ausadmin::print_header(\%header);

print P "\n";

if (defined $head_text) {
	print P $head_text;
}

foreach my $group (@group_list) {
	my $ng = new Newsgroup(name => $group);
	my $ngline = $ng->get_attr('ngline');
	print P "$group\t$ngline";
}

if (defined $foot_text) {
	print P $foot_text;
}

close(P);

exit(0);
