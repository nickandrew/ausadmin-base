#!/usr/bin/perl
#	@(#) post.pl - Simple NNRP post to a newsserver
#	post.pl [hostname [port [debug]]] < article
#
# Why doesn't this use Net::NNTP, Net::TCP or IO::Socket? For minimum
# dependancy on having _anything_ other than basic perl installed.
#
# $Source$
# $Revision$
# $Date$

use Socket;
use IO::Handle;
sub catch_alarm;

my $hostname = $ARGV[0] || $ENV{NNTPSERVER} || 'news';
my $port = $ARGV[1] || 119;
my $debug = $ARGV[2] || 0;

if ($port !~ /^\D$/) {
	$port = getservbyname('tcp', $port) || 119;
}

my $iaddr = inet_aton($hostname);
my $paddr = sockaddr_in($port, $iaddr);
my $proto = getprotobyname('tcp');

if (!socket(S, PF_INET, SOCK_STREAM, $proto)) {
	die "post.pl Unable to get a socket()!";
}

$SIG{'ALRM'} = \&catch_alarm;
alarm(120);

if (!connect(S, $paddr)) {
	die "Unable to connect to $hostname:$port";
}

S->autoflush(1);

my $line;

$line = <S>;
print "Got $line" if ($debug);
if ($line !~ /^200 /) { die "Expected 200, got $line"; }

print S "mode reader\r\n";
$line = <S>;
print "Got $line" if ($debug);
if ($line !~ /^200 /) { die "Expected 200 after mode reader, got $line"; }

print S "post\r\n";
$line = <S>;
print "Got $line" if ($debug);
if ($line !~ /^340 /) { die "Expected 340 after post, got $line"; }

# Now read from stdin and write to socket.

while (<STDIN>) {
	chop($line = $_);
	# Add the leading dot if needed
	if ($line =~ /^\./) {
		$line = '.' . $line;
	}

	print S "$line\r\n";
	print "Sending ... $line\n" if ($debug);
}

# And emit the closing .
print S ".\r\n";
$line = <S>;
print "Got $line" if ($debug);
if ($line !~ /^240 /) { die "Expected 240 after article, got $line"; }

print S "quit\r\n";

close(S);

exit(0);

sub catch_alarm {
	die "Caught alarm, post not done!";
}
