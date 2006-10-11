#!/usr/bin/perl
#	@(#) make-mrtg-newsgroups.pl - Create a mrtg.cfg file for all groups
#  Usage: make-mrtg-newsgroups.pl nglist_file head_file data_path > mrtg.cfg

my $nglist_file = shift @ARGV;
my $head_file = shift @ARGV;
my $data_path = shift @ARGV;

if (!open(H, "<$head_file")) {
	die "Unable to open $head_file $!";
}

if (!open(F, "<$nglist_file")) {
	die "Unable to open $nglist_file: $!";
}

if ($data_path !~ m/^\// || !-f $data_path) {
	die "$data_path does not exist or is not a fully-qualified pathname!\n";
}

# Output the entire header first
print STDOUT <H>;

my @groups;

# Then a sequence of paragraphs
while (<F>) {
	chomp;
	s/\s.*//;	# remove cruft after ng name
	push(@groups, $_);
}

close(F);

@groups = sort(@groups);

# Print a little paragraph for each newsgroup

foreach my $group (@groups) {

	print "Title[$group]: $group\n";
	print "PageTop[$group]: <h1>$group</h1>\n";
	print "Target[$group]: `/home/ausadmin/bin/mrtg_grep $data_path news:$group`\n";
	print "MaxBytes[$group]: 200\n";
	print "Options[$group]: perhour,growright,noo,nopercent\n";
	print "ShortLegend[$group]: art/hour\n";
	print "YLegend[$group]: Arts per hour\n";
	print "LegendI[$group]: Articles:&nbsp;\n";
	print "Legend1[$group]: Articles received per hour\n";
	print "\n";

}

exit(0);
