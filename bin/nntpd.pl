#!/usr/bin/perl -w
#	@(#) $Header$
#
#	Be a small NNTP server for syncing group lists
#	Intended to be run from tcpserver, so uses stdin/stdout

use lib '/home/ausadmin/perllib';

use Date::Format qw(time2str);

use Ausadmin qw();

my $errs = 0;
my $time = time();

my $remote = $ENV{TCPREMOTEHOST} || 'stdin';

my @hiers = qw(aus bne canb melb syd);

$| = 1;
chdir('/home/ausadmin');
open(LOG, ">>/home/ausadmin/tmp/nntpd.log");

logto("Connection from $remote\n");
out("200 ausadmin newsserver welcomes $remote\n");

$SIG{'ALRM'} = sub { out("503 timeout, exiting\n"); exit(0); };

while (1) {
	alarm(20);
	last if (!defined ($_ = readline(*STDIN)));
	$_ = lc($_);
	alarm(0);

	last if ($errs >= 4);
	chomp;
	s/\r//;

	my $now = time2str('%Y-%m-%d-%T', time());
	print LOG "$now < ", $_, "\n";

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

	if (/^list/) {
		out("215 listing active\n");
		list_hiers(undef);
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

# ---------------------------------------------------------------------------
# Output data in correct CRLF format to the socket.
# ---------------------------------------------------------------------------

sub out {
	my $s = shift;

	$s =~ s/\r//g;
	$s =~ s/\n/\r\n/g;

	print $s;
}

# ---------------------------------------------------------------------------
# Log an error to the logfile
# ---------------------------------------------------------------------------

sub logto {
	my $s = shift;

	my $now = time2str('%Y-%m-%d-%T', time());
	print LOG "$now > ", $s;
}

# ---------------------------------------------------------------------------
# Log an error by emailing it to me
# ---------------------------------------------------------------------------

sub log_error {
	my $s = shift;

	open(P, "|/usr/sbin/sendmail nick\@nick-andrew.net");
	print P <<EOF;
From: ausadmin\@aus.news-admin.org
To: nick\@nick-andrew.net
Subject: nntpd.pl error

Error:

$s
EOF
	close(P);
}

# ---------------------------------------------------------------------------
# Output the contents of a slice of the active file
# ---------------------------------------------------------------------------

sub list_active {
	my($hier, $regex) = @_;

	if (!open(F, "<data/$hier.data/grouplist")) {
		log_error("Cannot open data/$hier.data/grouplist\n");
		return;
	}

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

	if (!open(F, "<data/$hier.data/grouplist")) {
		log_error("Cannot open data/$hier.data/grouplist\n");
		return;
	}

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

sub list_hiers {
	my($regex) = @_;

	foreach my $hier (@hiers) {
		list_active($hier, $regex);
	}
	out(".\n");
}
