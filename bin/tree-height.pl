#!/usr/bin/perl
#	@(#) tree-height.pl - Calculate the height of the newsgroup tree image
#
#	$Revision$
#	$Source$
#	$Date$
#
#  Usage: tree-height.pl checkgroups

my $file = shift @ARGV || die "Usage: tree-height.pl filename";

open(F, "<$file") or die "Unable to open $f for input: $!";

my %groups;
my $group_count = 0;
my $line_count = 0;

while (<F>) {
	chomp;
	if (/^(\S+)\s+/) {
		# newsgroup name in $1
		my $g = $1;

		$groups{$g}++;
		$group_count++;

		# For all parent groups (up to 'aus'), create a hash entry too
		my $i;

		while (($i = rindex($g, '.')) > 0) {
			$g = substr($g, 0, $i);
			$groups{$g} += 0;
		}
	}
}

foreach (keys %groups) {
	if (! $groups{$_}) {
		$line_count++;
	}
}

print "Existing group count is $group_count\n";
print "Nonexistent parent group count is $line_count\n";
print "\n";

# Now output all lines in their correct order. Indent if it's a real newsgroup

foreach my $g (sort (keys %groups)) {
	if ($groups{$g}) {
		print "\t";
	}

	print $g, "\n";
}

exit(0);
