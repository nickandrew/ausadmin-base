#!/usr/bin/perl
#	@(#) $Header$
#

=head1 NAME

Post - A newsgroup post

=head1 SYNOPSIS

 my $post = new Post(template => $path);
 $post->substitute('STRING', 'Another string');
 $post->append('text');
 $post->send();

=cut

package Post;

use strict;

use Socket;
use IO::Handle;

sub catch_alarm;

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;

	if ($self->{template}) {
		open(TEM, "<$self->{template}") || die "Unable to open $self->{template} for reading: $!";

		my @text = <TEM>;
		$self->{text} = join('', @text);
	}

	$self->{text} ||= '';
	$self->{hostname} ||= $ENV{NNTPSERVER} || 'news';
	$self->{port} ||= 119;
	$self->{debug} ||= $ENV{AUSADMIN_NOPOST} || 0;

	return $self;
}

sub substitute {
	my($self,$s1, $s2) = @_;

	$self->{text} =~ s/$s1/$s2/g;
}

sub append {
	my $self = shift;
	my $s = shift;

	$self->{text} .= $s;
}

my $old_alarm;		# Keeps the SIGALRM catcher ref while posting

sub send {
	my $self = shift;

	my $debug = 1;

	if ($self->{debug}) {
		my $tempfile = "post.$$";

		print STDERR "Not posting text: in $tempfile\n";

		open(TEMP, ">$tempfile") || die "Unable to open $tempfile for write: $!";
		print TEMP $self->{text};
		close(TEMP);
		return;
	}

	my $port = $self->{port};
	$port = getservbyname('tcp', $port) || 119;

	my $hostname = $self->{hostname};
	my $iaddr = inet_aton($hostname);
	my $paddr = sockaddr_in($port, $iaddr);
	my $proto = getprotobyname('tcp');

	if (!socket(S, PF_INET, SOCK_STREAM, $proto)) {
		die "Unable to get a socket()!";
	}

	$old_alarm = $SIG{'ALRM'};

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

	# Now post what is in $self->{text}

	foreach $line (split(/\n/, $self->{text})) {
		# Add the leading dot if needed
		chomp($line);
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

	# Done! Reset alarm and go home
	$SIG{'ALRM'} = $old_alarm;

	return;
}

sub catch_alarm {
	die "Caught alarm, post not done!";
}

1;
