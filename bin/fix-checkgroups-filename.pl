#!/usr/bin/perl
#	@(#) $Id$
#	fix-checkgroups-filename.pl - Run once, to rename checkgroups.msg

my $datadir = "./data/aus.data";

if (!-d $datadir) {
	die "No directory $datadir -- cd?\n";
}

if (-f "$datadir/checkgroups.signed") {
	die "There is already a file data/checkgroups.signed - nothing to do.\n";
}

if (-f "$datadir/RCS/checkgroups.signed,v") {
	die "There is already a data/RCS/checkgroups.signed,v file\n";
}

if (!-f "$datadir/checkgroups.msg") {
	die "No file $datadir/checkgroups.msg";
}

my $rc = rename("$datadir/checkgroups.msg", "$datadir/checkgroups.signed");
if (! $rc) {
	print STDERR "rename $datadir/checkgroups.msg failed: $!\n";
}

mkdir("$datadir/RCS", 0750);

$rc = rename("$datadir/RCS/checkgroups.msg,v", "$datadir/RCS/checkgroups.signed,v");

if (! $rc) {
	print STDERR "rename $datadir/RCS/checkgroups.msg,v failed: $!\n";
}


exit(0);
