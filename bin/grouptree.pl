#!/usr/bin/perl

use GD;
$inputfile="ausgroups";
$outputfile="ausgroups.html";
$giffile="grouptree.gif";

if (!open(INFILE, "<$inputfile")) {
	print "Cannot open $inputfile: $!\n";
	exit(1);
}
if (!open(OUTFILE, ">$outputfile")) {
	print "Cannot open $outputfile: $!\n";
	exit(1);
}
if (!open(GIFFILE, ">$giffile")) {
	print "Cannot open $giffile: $!\n";
	exit(1);
}
undef @unsorted, @groups;

print OUTFILE "<html><title>Australian Newsgroups Overview</title><body bgcolor=\#FFFFFF>\n";
print OUTFILE "<map name=\"groups\">\n";

$yloc=1;
$height=`wc $inputfile | awk '{ print \$1 }'` * 13 + 40;
$width=300;
$descspace=300;

$im = new GD::Image($width,$height);
$white = $im->colorAllocate(255,255,255);
$black = $im->colorAllocate(0,0,0);
$blue = $im->colorAllocate(0,0,255);

$im->string(gdSmallFont, 0, 0, "aus", $black);
while (<INFILE>) {
	chop;
	$inline = $_;
	$inline =~ s/\t/:/;
	$inline =~ s/\t//g;
	($groupname, $description)=split(":", $inline, 2);
	$description="";
	($aus, $level1, $level2, $level3) = split(/\./, $groupname, 4);
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
			print OUTFILE "<area shape=rect coords=\"50, $yloc, 100, $botloc\" href=\"/cgi-bin/groupinfo.cgi?group=aus.$level1\">\n";
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
			print OUTFILE "<area shape=rect coords=\"100, $yloc, 150, $botloc\" href=\"/cgi-bin/groupinfo.cgi?group=aus.$level1.$level2\">\n";
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
		print OUTFILE "<area shape=rect coords=\"150, $yloc, 200, $botloc\" href=\"/cgi-bin/groupinfo.cgi?group=aus.$level1.$level2.$level3\">\n";
		$im->line(5,$yloc, 5, $yloc+12, $black);
		$im->line(105, $yloc+6, 147, $yloc+6, $black);
		$im->line(55, $yloc, 55, $yloc+12, $black);
		$im->line(105, $yloc, 105, $yloc+12, $black);
	}
	$newlevel1=0;
	$newlevel2=0;
}

binmode GIFFILE;
print GIFFILE $im->gif;
print OUTFILE "<img src=\"/cgi-bin/treegif.pl\" usemap=\"\#groups\" border=0><br>\n";
print OUTFILE "</map></body></html>\n";
close(INFILE);
close(OUTFILE);
close(GIFFILE);

exit(0);

