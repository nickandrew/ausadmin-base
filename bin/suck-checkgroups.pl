#!/usr/bin/perl
#	@(#) suck-checkgroups.pl - Another quick hack to find checkgroups msgs
#	$Header$

use Net::NNTP qw();

my $newsgroup = 'news.admin.hierarchies';
my $high_water = 'data/news.admin.hierarchies.lastread';

my $read_art = 0;

if (open(F, "<$high_water")) {
	chomp($read_art = <F>);
	close(F);
}

my $nntp = new Net::NNTP();
die "No NNTP server available" if (!defined $nntp);

my($narts, $low_art, $high_art, $gname) = $nntp->group($newsgroup);

die "We wanted $newsgroup but got $gname" if ($gname ne $newsgroup);

my $art = $read_art + 1;
$art = $low_art if ($art < $low_art);

my($sec,$min,$hour,$mday,$mon,$year) = localtime(time());
$mon++; $year += 1900;
my $ts = sprintf "%4d%02d%02d-%02d%02d%02d", $year,$mon,$mday,$hour,$min,$sec;
my $count = 0;

print "$newsgroup articles from $low_art to $high_art\n";

while ($art <= $high_art) {
	print "\tFetching header of $art\n";
	my $header_lr = $nntp->head($art);

	if (!defined $header_lr) {
		# Article does not exist, skip it
		$art++;
		next;
	}

	# Mark this article as read
	$read_art = $art;

	# Check if it is a "checkgroups"
	my $is_checkgroups = 0;

	foreach my $line (@$header_lr) {
		if ($line =~ /^Subject: /) {
			print "\t$line";
		}
		if ($line =~ /^Subject:.*checkgroups/i) {
			$is_checkgroups = 1;
			last;
		}
	}

	if ($is_checkgroups) {
		print "\tFetching body of $art\n";
		my $body_lr = $nntp->body($art);
		if (defined $body_lr) {
			$count++;
			my $fn = "tmp/checkgroups.$ts.$count";
			if (!open(F, ">$fn")) {
				die "Unable to open $fn for write: $!";
			}

			foreach my $line (@$header_lr) {
				print F $line;
			}

			print F "\n";

			foreach my $line (@$body_lr) {
				print F $line;
			}

			close(F);

			# Process it
			print "\tProcessing $fn\n";
			my $rc = system("bin/parse-checkgroups.pl data/checkgroups.ctl < $fn");
			if ($rc == 0) {
				unlink($fn);
			} else {
				print "\tProcessing failed, leaving $fn\n";
			}

			$art++;
			next;
		} else {
			# Article _now_ does not exist !?!
			$art++;
			next;
		}
	} else {
		# We ignore this, it is not a checkgroups
		$art++;
		next;
	}
}

print "Rewriting $high_water, last article was $read_art\n";

# Write the number of the last article read
if (!open(HW, ">$high_water")) {
	die "Unable to write $read_art to $high_water : $!";
}

print HW $read_art, "\n";
close(HW);

exit(0);


