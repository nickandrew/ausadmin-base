#!/usr/bin/perl
#	@(#) $Header$
#  Usage: make-mrtg-newsgroups-arrval.pl nglist_file head_file data_path > mrtg.cfg

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
	print "Target[$group]: `/usr/local/sbin/mrtg_grep $data_path news-arrival:$group`\n";
	print "MaxBytes[$group]: 20000\n";
	print "Options[$group]: gauge,growright,nopercent\n";
	print "ShortLegend[$group]: art/day\n";
	print "YLegend[$group]: Arts per day\n";
	print "LegendI[$group]: Articles:&nbsp;\n";
	print "Legend1[$group]: Articles received per day\n";
	print "\n";

}

exit(0);
