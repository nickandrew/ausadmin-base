#!/usr/bin/perl -w
#	@(#) $Id$
#	import-checkgroups.pl - Read a headerless checkgroups and create
#	newsgroup directories for all groups listed
#	
#	Usage: import-checkgroups.pl hierarchy-short-name < checkgroups-file

use strict;

use Newsgroup;

my $hier_name = shift @ARGV || die "Usage: import-checkgroups.pl hierarchy-short-name < checkgroups-file\n";

my $data_dir = "$hier_name.data/Newsgroups";

while (<STDIN>) {
	chomp;
	if (/^([^\t]+)\s+(.*)/) {
		my $name = $1;
		my $ngline = $2;

		if ($name !~ /^$hier_name\./o) {
			print STDERR "Refused, out of hierarchy: $name\n";
			next;
		}

		my $n = new Newsgroup(name => $name, datadir => $data_dir);

		if (-e "$data_dir/$name") {
			print STDERR "Already exists: $name\n";
			next;
		}

		$n->create();

		$n->set_attr("ngline", $ngline . "\n", 'Imported from checkgroups file');
	} else {
		print STDERR "Invalid line (ignored): $_\n";
	}
}

print "All done.\n";
exit(0);
