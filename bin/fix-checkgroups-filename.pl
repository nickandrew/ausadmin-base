#!/usr/bin/perl
#	@(#) $Id$
#	fix-checkgroups-filename.pl - Run once, to rename checkgroups.msg

my $data_dir = "./data";

if (!-d $data_dir) {
	die "No directory $data_dir -- cd?\n";
}

if (-f "$data_dir/checkgroups.signed") {
	die "There is already a file data/checkgroups.signed - nothing to do.\n";
}

if (-f "$data_dir/RCS/checkgroups.signed,v") {
	die "There is already a data/RCS/checkgroups.signed,v file\n";
}

if (!-f "$data_dir/checkgroups.msg") {
	die "No file $data_dir/checkgroups.msg";
}

my $rc = rename("$data_dir/checkgroups.msg", "$data_dir/checkgroups.signed");
if (! $rc) {
	print STDERR "rename $data_dir/checkgroups.msg failed: $!\n";
}

mkdir("$data_dir/RCS", 0750);

$rc = rename("$data_dir/RCS/checkgroups.msg,v", "$data_dir/RCS/checkgroups.signed,v");

if (! $rc) {
	print STDERR "rename $data_dir/RCS/checkgroups.msg,v failed: $!\n";
}


exit(0);
