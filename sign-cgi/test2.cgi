#!/usr/bin/perl -w
#
# Server can connect out to port 80 and port 443
# Server cannot connect to port 119, 22 or 12345

use strict;

use CGI::Carp qw(carp confess croak cluck fatalsToBrowser);
use Socket;
use IO::Handle;

print "Content-Type: text/plain\n\n";

my $hostname;
my $port;

sub catch_alarm {
	print "Caught alarm doing $hostname : $port\n";
}

my @test_servers = qw(
	news.usenetnews.us:119
	corp.supernews.com:119
	freenews.iinet.net.au:119
	news.pacific.net.au:119
	67.19.189.20:119
	67.19.189.20:80
	67.19.189.20:443
	67.19.189.20:22
	67.19.189.20:25
	67.19.189.20:12345
);

foreach $hostname (@test_servers) {
	if ($hostname =~ /(.+):(.+)/) {
		($hostname, $port) = ($1, $2);
	} else {
		$port = 119;
	}

	my $iaddr = inet_aton($hostname);
	if (! $iaddr) {
		print "No server $hostname\n";
		next;
	}

	my $paddr = sockaddr_in($port, $iaddr);
	my $proto = getprotobyname('tcp');

	if (!socket(S, PF_INET, SOCK_STREAM, $proto)) {
		die "Cannot get a socket\n";
	}

	$SIG{'ALRM'} = \&catch_alarm;

	alarm(10);

	if (!connect(S, $paddr)) {
		print "Cannot connect to $hostname port $port\n";
		next;
	}

	print "Connected to $hostname port $port\n";
	S->autoflush(1);

	if (0) {
		test_nntp();
	}

	close(S);
}

alarm(0);

exit(0);

sub test_nntp {
	my $line = <S>;
	print "From $hostname: $line\n";
	if ($line !~ /^200 /) {
		print "Not much hope there\n";
		next;
	}

	print S "mode reader\r\n";
	$line = <S>;
	print "Got $line";
	if ($line !~ /^200 /) {
		print "Not much hope there\n";
		next;
	}

	print S "post\r\n";
	$line = <S>;
	print "Got $line";
	if ($line !~ /^340 /) {
		print "Not much hope there\n";
		next;
	}
}
