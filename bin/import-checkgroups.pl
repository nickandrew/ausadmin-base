#!/usr/bin/perl -w
#	@(#) $Id$
#	import-checkgroups.pl - Read a headerless checkgroups and create
#	or update newsgroup directories for all groups listed
#	
#	Usage: import-checkgroups.pl hierarchy-short-name < checkgroups-file

use strict;

use Newsgroup qw();

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

		if (! -e "$data_dir/$name") {
			print "Creating newsgroup: $name\n";
			$n->create();
		}

		# "ngline" is a line ending in \n
		$ngline .= "\n";
		my $old_ngline = $n->get_attr('ngline');

		if (!defined $old_ngline || $old_ngline ne $ngline) {
			print "Updating $name ngline $ngline\n";
			$n->set_attr("ngline", $ngline . "\n", 'Imported from checkgroups file');
		}
	} else {
		print STDERR "Invalid line (ignored): $_\n";
	}
}

print "All done.\n";
exit(0);
