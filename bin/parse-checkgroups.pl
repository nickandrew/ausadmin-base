#!/usr/bin/perl
#	@(#) $Header$
#
#	A quick hack at importing checkgroups messages.
#
# Usage: parse-checkgroups.pl conditions-file < raw-checkgroups-file

use strict;

use Newsgroup qw();

my @lines;

while (<STDIN>) {
	chomp;
	push(@lines, $_);
}

my $cond_file = shift @ARGV || usage();

sub usage {
	die "Usage: parse-checkgroups.pl conditions-file\n";
}

if (!open(C, "<$cond_file")) {
	die "Unable to open $cond_file for read: $!";
}

# Format of the conditions file:
#
# hiearchy-name
# regexp-condition
# regexp-condition
# ...
# <empty line>
# hiearchy-name
# regexp-condition
# regexp-condition
# ...
# <empty line>
#

my $state = 'hier';
my $hierarchy_name = '';
my $satisfied = 0;
my $rc = 4;

while (<C>) {
	chomp;

	next if (/^#/);

	if ($state eq 'hier' && $_ ne '') {
		$hierarchy_name = $_;
		$state = 'condition';
		$satisfied = 1;
		next;
	}

	# State must be 'condition'

	if ($_ eq '') {
		if ($satisfied) {
			# Import the file
			import_checkgroups($hierarchy_name, \@lines);
			print "Imported.\n";
			$rc = 0;
			last;
		}

		# Not satisfied, ignore blank line
		$state = 'hier';
		next;
	}

	# It must be a condition to check.

	# If we did not satisfy some previous condition, no point checking this one.
	if (!$satisfied) {
		next;
	}

	# Check the condition against all saved lines
	my $regex = $_;
	my $found = 0;

	foreach my $line (@lines) {
		if ($line =~ /^$regex/) {
			$found = 1;
			last;
		}
	}

	if (!$found) {
		$satisfied = 0;
	}
}

exit($rc);

# Now import ...
#

sub import_checkgroups {
	my $hier_name = shift;
	my $line_lr = shift;

	print "Importing checkgroups for $hier_name\n";

	mkdir("$hier_name.data", 0755);
	mkdir("$hier_name.data/Newsgroups", 0755);

	my $datadir = "$hier_name.data";

	foreach (@$line_lr) {

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
				print "Updating $name ngline to $ngline\n";
				$n->set_attr("ngline", $ngline, 'Imported from checkgroups file');
			}
		}
	}

	print "$hier_name is complete.\n";
}
