#!/usr/bin/perl
#	@(#) analyse.pl - Produce a slow, bulky analysis of common
#	characteristics of votes received for a newsgroup.

=head1 NAME

analyse-messages.pl - Analyse vote messages to find patterns

=head1 SYNOPSIS

analyse-messages.pl [-di] filename ...

=head1 DESCRIPTION

This program performs a very slow and thorough analysis of the votes
received for the specified vote.

=cut

use Getopt::Std;
use lib 'bin';
use Message;
use Vote;

use vars qw($opt_d $opt_i);

getopts('di');

my @list;


foreach my $path (@ARGV) {
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

	if (exists $data_hr->{mailer}) {
		my $lr = $data_hr->{mailer};
		foreach (@{$lr}) {
			push(@{$mailers{$_}}, $r);
		}
	}

	if (exists $data_hr->{ip}) {
		my $lr = $data_hr->{ip};
		foreach (@{$lr}) {
			push(@{$ips{$_}}, $r);
		}
	}
}

mailer_report(\%mailers);
ip_report(\%ips);

exit(0);


# Now report, by ip ...

sub ip_report {
	my $ips_hr = shift;

	print "\nIP Report\n";

	foreach my $ip (sort (keys %$ips_hr)) {
		print "\nIP: $ip\n";
		my $lr = $ips_hr->{$ip};
		foreach (@$lr) {
			printf "\tMessage: %s\n", $_->{path};
		}
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
