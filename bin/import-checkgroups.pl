#!/usr/bin/perl -w
#	@(#) $Id$
#	import-checkgroups.pl - Read a headerless checkgroups and create
#	or update newsgroup directories for all groups listed
#	
#	Usage: import-checkgroups.pl hierarchy-short-name < checkgroups-file

use strict;

use Newsgroup qw();

my $hier_name = shift @ARGV || die "Usage: import-checkgroups.pl hierarchy-short-name < checkgroups-file\n";

mkdir("$hier_name.data", 0755);
mkdir("$hier_name.data/Html", 0755);
mkdir("$hier_name.data/Newsgroups", 0755);

my $datadir = "$hier_name.data";

while (<STDIN>) {
	chomp;
	if (/^([^\t]+)\t+\s*(.+)/) {
		my $name = $1;
		my $ngline = $2;

		if ($name !~ /^$hier_name\./o) {
			print "Refused, out of hierarchy: $name\n";
			next;
		}

		if (! Newsgroup::valid_name($name)) {
			print "Refused, bad newsgroup name: $name\n";
			next;
		}

		my $n = new Newsgroup(name => $name, datadir => $datadir);

		if (! -e "$datadir/$name") {
			print "Creating newsgroup: $name\n";
			$n->create();
		}

		# "ngline" is a line ending in \n
		$ngline .= "\n";
		my $old_ngline = $n->get_attr('ngline');

		if (!defined $old_ngline || $old_ngline ne $ngline) {
			print "Updating $name ngline $ngline\n";
			$n->set_attr("ngline", $ngline, 'Imported from checkgroups file');
		}
	} else {
		print "Invalid line (ignored): $_\n";
	}
}

print "All done.\n";
exit(0);
