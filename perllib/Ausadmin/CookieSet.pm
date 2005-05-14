#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
# An instance of Ausadmin::CookieSet is a list of cookies to be sent to the
# named script. This instance also looks up cookies for a caller.

package Ausadmin::CookieSet;

use IO::File qw();

use Ausadmin qw();

# Cookies are supposed to be opaque to the end-user.
my $id_cookie_name = 'GROVER';

# ---------------------------------------------------------------------------
# Create a new instance of Ausadmin::CookieSet.
# ---------------------------------------------------------------------------

sub new {
	my ($class, $cgi) = @_;

	die "Need cgi" if (! $cgi);

	my $self = {
		cgi => $cgi,
		cookies => { },
	};

	bless $self, $class;
	return $self;
}

# ---------------------------------------------------------------------------
# Return the value of a named cookie (from our list or CGI)
# ---------------------------------------------------------------------------

sub getCookie {
	my ($self, $name) = @_;

	if (exists $self->{cookies}->{$name}) {
		return $self->{cookies}->{$name};
	}

	return $self->{cgi}->cookie($name);
}

# ---------------------------------------------------------------------------
# Return a listref of cookies to send to the client
# ---------------------------------------------------------------------------

sub getList {
	my $self = shift;

	my @list = values(%{$self->{cookies}});
	return \@list;
}

# ---------------------------------------------------------------------------
# Add or replace a cookie in our list
# ---------------------------------------------------------------------------

sub addCookie {
	my ($self, $cookie) = @_;
	my $name = $cookie->name();

	$self->{cookies}->{$name} = $cookie;
}

# ---------------------------------------------------------------------------
# All site visitors receive a yummy cookie.
# ---------------------------------------------------------------------------

sub idCookie {
	my $self = shift;

	if ($self->{original_id}) {
		return $self->{original_id};
	}

	my $cgi = $self->{cgi};
	my $value = $cgi->cookie($id_cookie_name);

	$self->{original_id} = $value;

	if ($value) {
		# TODO ... need to verify that this is a valid ID cookie
		return $value;
	}

	# Make up a random one and assign it, next execution
	$value = randomValue(16);
	my $cookie = $cgi->cookie(
		-name => $id_cookie_name,
		-value => $value,
		-expires => '+3m',
		-path => '/',
		-domain => Ausadmin::config('cookie_domain'),
		-secure => 1,
	);

	# TODO ... need to save this value in our database
	$self->{cookies}->{$id_cookie_name} = $cookie;
	$self->{new_id} = $value;
	return undef;
}

# ---------------------------------------------------------------------------
# Return identifying cookie
# ---------------------------------------------------------------------------

sub getID {
	my $self = shift;

	if (! exists $self->{original_id}) {
		$self->{original_id} = $self->{cgi}->cookie($id_cookie_name);
		# TODO ... need to verify that this is a valid ID cookie
	}

	return $self->{original_id} || '';
}

# ---------------------------------------------------------------------------
# Return a random hex string of specified size x 2
# ---------------------------------------------------------------------------

sub randomValue {
	my $size = shift;

	my $fh = IO::File->new('/dev/urandom', IO::File::O_RDONLY());
	if (! $fh) {
		die "Unable to open /dev/urandom for read";
	}

	my $buf;
	sysread($fh, $buf, $size);
	$fh->close();

	my $rv = unpack("H*", $buf);
	return $rv;
}

1;
