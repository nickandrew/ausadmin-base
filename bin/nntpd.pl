#!/usr/bin/perl -w
#	@(#) $Header$
#
#	Be a small NNTP server for syncing group lists
#	Intended to be run from tcpserver, so uses stdin/stdout

use lib '/home/ausadmin/bin';

use Ausadmin qw();

my $errs = 0;
my $time = time();

my @hiers = qw(aus bne canb melb syd);

$| = 1;
chdir('/home/ausadmin');
open(LOG, ">>/home/ausadmin/tmp/nntpd.log");

out("200 ausadmin newsserver welcomes $ENV{TCPREMOTEHOST}\n");

while (<STDIN>) {
	last if ($errs >= 4);
	chomp;
	s/\r//;

	my $cmd = $_;
	print LOG "$time < ", $_, "\n";

	if (/mode reader/) {
		out("200 no-op\n");
		next;
	}

	if (/list active( (.*))?/) {
		my $regex = $2;
		if ($regex) {
			out("215 listing active matching $regex\n");

			# Turn a fileglob into a proper regex:
			#	. becomes \.
			#	* becomes .*
			$regex =~ s/\./\\./g;
			$regex =~ s/\*/.*/g;
		} else {
			out("215 listing active\n");
		}

		foreach my $hier (@hiers) {
			list_active($hier, $regex);
		}
		out(".\n");
		next;
	}

	if (/list newsgroups( (.*))?/) {
		my $regex = $2;
		if ($regex) {
			out("215 listing newsgroups matching $regex\n");
			# Turn a fileglob into a proper regex:
			#	. becomes \.
			#	* becomes .*
			$regex =~ s/\./\\./g;
			$regex =~ s/\*/.*/g;
		} else {
			out("215 listing newsgroups\n");
		}

		foreach my $hier (@hiers) {
			list_newsgroups($hier, $regex);
		}
		out(".\n");
		next;
	}

	if (/^quit/) {
		last;
	}

	out("500 Command not recognized\n");
	$errs++;
}

out("205 Goodbye!\n");

exit(0);

sub out {
	my $s = shift;

	print LOG "$time > ", $s;

	$s =~ s/\r//g;
	$s =~ s/\n/\r\n/g;

	print $s;
}
 
sub list_active {
	my($hier, $regex) = @_;

	open(F, "<$hier.data/grouplist") || return;

	while (<F>) {
		m/(\S+)\s*(.*)/;
		my($group, $description) = ($1, $2);

		if ($regex) {
			next unless ($group =~ /^$regex$/);
		}

		my $mod = 'y';
		if ($description =~ /moderated/i) {
			$mod = 'm';
		}

		out("$group 00000002 00000001 $mod\n");
	}

	close(F);
}

 
sub list_newsgroups {
	my($hier, $regex) = @_;

	open(F, "<$hier.data/grouplist") || return;

	while (<F>) {
		m/(\S+)\s+(.*)/;
		my($group, $description) = ($1, $2);

		if ($regex) {
			next unless ($group =~ /^$regex$/);
		}

		out("$group\t$description\n");
	}

	close(F);
}

