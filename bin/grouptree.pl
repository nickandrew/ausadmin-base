#!/usr/bin/perl
#	@(#) grouptree.pl - Create a graphical representation of the
#	newsgroup hierarchy. In conjunction with this, create an HTML
#	file which maps rectangles in the graphical file to the
#	description of each newsgroup.
#
# $Source$
# $Revision$
# $Date$

use GD;

my $inputfile="checkgroups";
my $outputfile="checkgroups.html";
my $pngfile="grouptree.png";

if (!open(INFILE, "<$inputfile")) {
	die "Cannot open $inputfile: $!\n";
}

if (!open(OUTFILE, ">$outputfile")) {
	die "Cannot open $outputfile: $!\n";
}

if (!open(PNGFILE, ">$pngfile")) {
	die "Cannot open $pngfile: $!\n";
}

#undef @unsorted;
#undef @groups;

print OUTFILE "<html><title>Australian Newsgroups Overview</title><body bgcolor=\#FFFFFF>\n";
print OUTFILE "<map name=\"groups\">\n";

$yloc=1;
my $line_height = 13;

# Read the INFILE and store the group names and descriptions. Also
# calculate how tall the graphical file must be (in pixels).

my $group_hr = { };

while (<INFILE>) {
	chomp;
	my $inline = $_;
	$inline =~ s/\t/:/;
	$inline =~ s/\t//g;
	my($groupname, $description) = split(':', $inline, 2);
	$group_hr->{$groupname}->{description} = $description;

	# This is a real group, so count it
	$group_hr->{$groupname}->{count}++;

	# Now make sure a hash entry exists for all parent groups
	my $g = $groupname;
	my $i;

	while (($i = rindex($g, '.')) > 0) {
		$g = substr($g, 0, $i);
		$group_hr->{$g}->{count} += 0;
	}
}

close(INFILE);

my $lines = scalar(keys %$group_hr);

my $height = $lines * 13 + 40;
my $width = 300;
my $descspace = 300;

$im = new GD::Image($width,$height);
$white = $im->colorAllocate(255,255,255);
$black = $im->colorAllocate(0,0,0);
$blue = $im->colorAllocate(0,0,255);

$im->string(gdSmallFont, 0, 0, "aus", $black);

# Now go through the sorted group list in memory

foreach my $groupname (sort (keys %$group_hr)) {

	# Ignore all parent groups which do not exist
	next if ($group_hr->{$groupname}->{count} == 0);

	# Put the description in as well
	my $description = $group_hr->{$groupname}->{description};

	my($aus, $level1, $level2, $level3) = split(/\./, $groupname, 4);
	if ($level2 ne $oldlevel2) {
		$oldlevel2 = $level2;
		$newlevel2 = 1;
	}
	if ($level1 ne $oldlevel1) {
		$oldlevel1 = $level1;
		$newlevel1 = 1;
	}
	if ($newlevel1) { 
		$yloc+=13;
		$lstr = $level1;
		$color=$black;
		$botloc=$yloc+12;
		if (!$level2) {
			$color=$blue;
			print OUTFILE "<area shape=rect coords=\"50, $yloc, 100, $botloc\" href=\"/cgi-bin/groupinfo.pl?group=aus.$level1\">\n";
		}
		$im->string(gdSmallFont, 50, $yloc, $level1, $color);
		$im->line(5,$yloc, 5, $yloc+12, $black);
		$im->line(5, $yloc+6, 48, $yloc+6, $black);
		$im->line(55, $yloc-6, 55, $yloc-1, $white);
	}
	
	if ($newlevel2 && $level2 ne '')  {
		$yloc+=13;
		$lstr = $level2;
		$color=$black;
		$botloc=$yloc+12;
		if (!$level3) {
			$color=$blue;
			print OUTFILE "<area shape=rect coords=\"100, $yloc, 150, $botloc\" href=\"/cgi-bin/groupinfo.pl?group=aus.$level1.$level2\">\n";
		}
		$im->string(gdSmallFont, 100, $yloc, $level2, $color);
		$im->line(5,$yloc, 5, $yloc+12, $black);
		$im->line(55, $yloc+6, 97, $yloc+6, $black);
		$im->line(55, $yloc, 55, $yloc+12, $black);
		$im->line(105, $yloc-6, 105, $yloc-1, $white);
	}
	
	if ($level3 ne '') {
		$yloc+=13;
		$im->string(gdSmallFont, 150, $yloc, $level3, $blue);
		$im->string(gdSmallFont, $descspace, $yloc, $description, $black);
		$botloc=$yloc+12;
		print OUTFILE "<area shape=rect coords=\"150, $yloc, 200, $botloc\" href=\"/cgi-bin/groupinfo.pl?group=aus.$level1.$level2.$level3\">\n";
		$im->line(5,$yloc, 5, $yloc+12, $black);
		$im->line(105, $yloc+6, 147, $yloc+6, $black);
		$im->line(55, $yloc, 55, $yloc+12, $black);
		$im->line(105, $yloc, 105, $yloc+12, $black);
	}
	$newlevel1=0;
	$newlevel2=0;
}

binmode PNGFILE;
print PNGFILE $im->png;
print OUTFILE "<img src=\"/cgi-bin/treepng.pl\" usemap=\"\#groups\" border=0><br>\n";
print OUTFILE "</map></body></html>\n";

close(OUTFILE);
close(PNGFILE);

exit(0);

