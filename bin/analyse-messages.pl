#!/usr/bin/perl
#	@(#) analyse.pl - Produce a slow, bulky analysis of common
#	characteristics of votes received for a newsgroup.

=head1 NAME

analyse-messages.pl - Analyse vote messages to find patterns

=head1 SYNOPSIS

 analyse-messages.pl [-dir] < tally-pathname
 analyse-messages.pl [-dir] path-list

=head1 DESCRIPTION

This program performs a very slow and thorough analysis of the messages
received for the specified vote.

Option B<-d> is unused.

Option B<-i> causes the program to print, to STDOUT, the contents of all
interesting headers in each message.

Option B<-r> causes the program to add all the IP addresses it finds in
Received: headers to its IP cross-reference.

=cut

use Getopt::Std;
use Socket;

use lib 'bin';
use Message;
use Vote;

use vars qw($opt_d $opt_i $opt_r);

getopts('dir');

my $opt_check_received = $opt_r;

my @list;
my @path_list;

if (@ARGV) {
	@path_list = @ARGV;
} else {
	# Read the tally contents for this vote on stdin

	while (<STDIN>) {
		chomp;
		my($email,$vote,$choice,$ts,$path) = split(/\s+/);
		if ($path ne '' && -f $path) {
			push(@path_list, $path);
		}
	}
}

foreach my $path (@path_list) {
	my $r = { path => $path };
	my $m = new Message();
	$m->parse_file($r->{path});
	$r->{message} = $m;
	push(@list, $r);
}

# Now find some interesting facts about these messages...

# Go through every message
foreach my $r (@list) {
	my $m = $r->{message};

	my $data_hr = $m->header_info();
	$r->{data_hr} = $data_hr;

	if ($opt_i) {
		# And print the interesting ones
		Message::print_interesting($data_hr);
	}
}

# Now we do a cross-reference by mailer and ip ...

my %mailers;
my %ips;

foreach my $r (@list) {
	my $data_hr = $r->{data_hr};
	my $m = $r->{message};

	if (exists $data_hr->{mailer}) {
		my $lr = $data_hr->{mailer};
		foreach (@$lr) {
			push(@{$mailers{$_}}, $r);
		}
	}

	if (exists $data_hr->{ip}) {
		my $lr = $data_hr->{ip};
		foreach (@$lr) {
			push(@{$ips{$_}}, $r);
		}
	}

	if ($opt_check_received) {
		# Go through each header in this message, parsing any Received headers
		my @headers = $m->headers();

		foreach my $hdr (@headers) {
			next unless ($hdr =~ /^Received: /);
			my $data_hash = $m->check_received($hdr);

			# Interesting data types are: src-ip, src-fw-ip, src-ident

			# Now grab any 'src-ip' types
			if (exists $data_hash->{'src-ip'}) {
				my $lr = $data_hash->{'src-ip'};
				foreach (@$lr) {
					push(@{$ips{$_}}, $r);
				}
			}
		}
	}
}

# Remove duplicate messages in the mailers and ips lists

#foreach my $k (keys %mailers) {
#	my $lr = $mailers{$k};
#	my %hash = map { $_ => 1 } @$lr;
#
#	my @list = keys %hash;
#	$mailers{$k} = \@list;
#}

#foreach my $k (keys %ips) {
#	my $lr = $ips{$k};
#	dump_ref($lr, 0);
#	my %hash = map { $_ => 1 } @$lr;
#
#	my @list = keys %hash;
#	print "List is @list.\n";
#	$ips{$k} = \@list;
#}

# print "\nDumping IPs\n\n";
# dump_ref(\%ips);


ip_report(\%ips);
mailer_report(\%mailers);

exit(0);

sub dump_ref {
	my $ref = shift;
	my $level = shift || 0;

	if (!ref $ref) {
		printf "%sString: %s\n", ' ' x $level, $ref;
		return;
	}

	my $ht = ref $ref;

	if ($ht eq 'HASH') {
		printf "%sHash:\n", ' ' x $level;
		foreach my $r (sort (keys %$ref)) {
			printf "%sKey:\n", ' ' x ($level + 1);
			dump_ref($r, $level + 2);
			printf "%sValue:\n", ' ' x ($level + 1);
			dump_ref($ref->{$r}, $level + 2);
		}
		return;
	}

	if ($ht eq 'ARRAY') {
		foreach my $r (@$ref) {
			printf "%sValue:\n", ' ' x ($level + 1);
			dump_ref($r, $level + 2);
		}
		return;
	}

	if ($ht eq 'SCALAR') {
		printf "%sSCALAR: %s\n", ' ' x $level, $ref;
		return;
	}

	printf "%sUnknown: %s\n", ' ' x $level, $ht;
}



# Now report, by ip ...

sub ip_report {
	my $ips_hr = shift;

	print "\nIP Report\n";

	foreach my $ip (sort (keys %$ips_hr)) {
		print "\n", '-' x 70, "\n";
		my($name,$aliases,$addrtype,$length,@addrs) = gethostbyaddr(inet_aton($ip), AF_INET);
		printf "\nIP: %-15.15s  Name: %s\n", $ip, $name;

		my $lr = $ips_hr->{$ip};
		my $count = 0;
		my $str = '';
		my @lines;
		my @unique;
		my %seen;
		foreach my $r (@$lr) {
			my $m = $r->{message};

			if (!exists $seen{$r->{path}}) {
				$str .= ' ' . $r->{path};

				push(@unique, $r);
				push(@lines, sprintf("\tMessage: %s (%s %s)\n", $r->{path}, $m->{votes}->[0]->[0], $m->{votes}->[0]->[1]));

				$seen{$r->{path}} = 1;
				$count++;
			}
		}

		if ($count > 1) {
			printf "\tCount: %d\n", $count;
			printf "\tPaths:%s\n", $str;
		}

		foreach (@lines) {
			print $_;
		}

		# Now show the interesting fields of all these messages
		# From
		foreach my $r (@unique) {
			my $m = $r->{message};
			my $data_hr = $r->{data_hr};

			if (exists $data_hr->{from}) {
				print "\tFrom:";
				foreach (@{$data_hr->{from}}) {
					print ' ', $_;
				}
				print "\n";
			}

			if (exists $data_hr->{mailer}) {
				print "\tMailer:";
				foreach (@{$data_hr->{mailer}}) {
					print ' ', $_;
				}
				print "\n";
			}
		}

		# Ah fuck it, just show each message's headers
		foreach my $r (@unique) {
			my $m = $r->{message};
			my @headers = $m->headers();
			print "\tMessage: ", $m->{path}, "\n";
			foreach (@headers) {
				print "\t    $_\n";
			}
			print "\n";
		}
		print "\n\n";


	}

	print "\nEnd of IP Report\n";
}

# Now report, by mailer ...

sub mailer_report {
	my $mailers_hr = shift;

	print "\nMailer Report\n";

	foreach my $mailer (sort (keys %$mailers_hr)) {
		print "\nMailer: $mailer\n";
		my $lr = $mailers_hr->{$mailer};
		foreach (@$lr) {
			printf "\tMessage: %s\n", $_->{path};
		}
	}

	print "\nEnd of Mailer Report\n";
}
