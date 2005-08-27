#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
# An instance of Ausadmin::CookieSet is a list of cookies to be sent to the
# named script. This instance also looks up cookies for a caller.

package Ausadmin::CookieSet;

use Carp qw(confess);
use Date::Format qw(time2str);
use Date::Parse qw(str2time);
use IO::File qw();

use Ausadmin qw();

# Cookies are supposed to be opaque to the end-user.
my $id_cookie_name = 'GROVER';
my $login_cookie_name = 'SNUFFY';

# ---------------------------------------------------------------------------
# Create a new instance of Ausadmin::CookieSet.
# ---------------------------------------------------------------------------

sub new {
	my ($class, $cgi, $sqldb) = @_;

	die "Need cgi" if (! $cgi);
	die "Need sqldb" if (! $sqldb);

	my $self = {
		cgi => $cgi,
		sqldb => $sqldb,
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

sub getIDToken {
	my $self = shift;

	if ($self->{original_id}) {
		return $self->{original_id};
	}

	my $cgi = $self->{cgi};
	my $id_token = $cgi->cookie($id_cookie_name);

	$self->{original_id} = $id_token;

	if ($id_token) {
		# TODO ... need to verify that this is a valid ID cookie
		return $id_token;
	}

	# Make up a random one and assign it, next execution
	$id_token = randomValue(16);
	my $lifetime = 3650;

	my $now = time2str('%Y-%m-%d %T', time());
	my $future = time2str('%Y-%m-%d %T', time() + $lifetime * 86400);

	$self->{sqldb}->insert('ident',
		id_token => $id_token,
		created_on => $now,
		last_used_on => $now,
		expires_on => $future,
		ip_address => $ENV{REMOTE_ADDR},
		uri => $ENV{REQUEST_URI},
	);

	my $cookie = $cgi->cookie(
		-name => $id_cookie_name,
		-value => $id_token,
		-expires => "+${lifetime}d",
		-path => '/',
		-domain => Ausadmin::config('cookie_domain'),
		-secure => 1,
	);

	# TODO ... need to save this value in our database
	$self->{cookies}->{$id_cookie_name} = $cookie;
	$self->{new_id} = $id_token;
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
# Figure out logged-in username and return it
# ---------------------------------------------------------------------------

sub getUserName {
	my $self = shift;

	if ($self->{login_username}) {
		return $self->{login_username};
	}

	if (! getIDToken($self)) {
		# You can't be logged in if you don't present a valid ID Token
		return '';
	}

	if (! exists $self->{login_username}) {
		my $login_token = $self->{cgi}->cookie($login_cookie_name);

		if (! $login_token) {
			# We are not logged in
			return '';
		}

		# TODO Lookup the random value in the login table to associate that
		# with a username
		my $sqldb = $self->{sqldb};
		my $rows = $sqldb->extract("select username, expires_on from logged_in where login_token = ?", $login_token);
		if (! $rows || ! $rows->[0]) {
			# We are not logged in
			return '';
		}

		my ($username, $expires_on) = @{$rows->[0]};

		my $expires_ts = str2time($expires_on);
		if ($expires_ts < time() + 360 * 86400) {
			# Time to refresh the expiry date on the cookie
			my $cookie = _loginCookie($self, $login_token, 365);
			addCookie($self, $cookie);
		}

		$self->{login_username} = $username;
		my $id_token = $self->{cgi}->cookie($id_cookie_name);

		# Update the rows in the logged_in table which track us
		# as we navigate the site
		$sqldb->execute("update logged_in set id_token = ?, last_used_on = ?, last_ip_address = ?, last_uri = ? where username = ?",
			$id_token,
			time2str('%Y-%m-%d %T', time()),
			$ENV{REMOTE_ADDR},
			$ENV{REQUEST_URI},
			$username,
		);

	}

	return $self->{login_username} || '';
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

# ---------------------------------------------------------------------------
# Create a new login and log the user in as $username
# ---------------------------------------------------------------------------

sub doLogin {
	my ($self, $username) = @_;

	my $sqldb = $self->{sqldb};

	my $xuser = $sqldb->fetch1("select username from user where username = ? and active = 1", $username);
	if (! $xuser) {
		die "Cannot login as $username which does not exist";
	}

	# TODO ... insert into the login record
	my $login_token = randomValue(16);
	my $lifetime = 365;
	my $now = time2str('%Y-%m-%d %T', time());
	my $future = time2str('%Y-%m-%d %T', time() + $lifetime * 86400);
	my $id_token = $self->{cgi}->cookie($id_cookie_name);

	$sqldb->insert('logged_in',
		username => $username,
		login_token => $login_token,
		id_token => $id_token,
		logged_in_on => $now,
		expires_on => $future,
		last_used_on => $now,
		last_ip_address => $ENV{REMOTE_ADDR},
		last_uri => $ENV{REQUEST_URI},
	);

	$sqldb->insert('login_history',
		id => 0,
		is_login => 1,
		username => $username,
		id_token => $id_token,
		created_on => $now,
		ip_address => $ENV{REMOTE_ADDR},
		uri => $ENV{REQUEST_URI},
	);

	my $cookie = _loginCookie($self, $login_token, $lifetime);
	addCookie($self, $cookie);

	$self->{login_username} = $username;
}

# ---------------------------------------------------------------------------
# Return a login cookie
# ---------------------------------------------------------------------------

sub _loginCookie {
	my ($self, $login_token, $lifetime) = @_;

	my $cgi = $self->{cgi};
	if (! $cgi) {
		confess "No CGI";
	}

	my $cookie = $cgi->cookie(
		-name => $login_cookie_name,
		-value => $login_token,
		-expires => "+${lifetime}d",
		-path => '/',
		-domain => Ausadmin::config('cookie_domain'),
		-secure => 1,
	);

	return $cookie;
}

# ---------------------------------------------------------------------------
# If the user sent a POST form with login details, then log us in
# and continue with the script
# This function also processes logout
# ---------------------------------------------------------------------------

sub testActionLogin {
	my $self = shift;

	my $cgi = $self->{cgi};
	my $sqldb = $self->{sqldb};

	if ($ENV{REQUEST_METHOD} ne 'POST') {
		# We only perform login on a POST request
		return;
	}

	my $action = $cgi->param('action') || '';

	if ($action eq 'logout') {
		my $username = getUserName($self);
		if ($username) {
			doLogout($self, $username);
		}

		delete $self->{login_username};
		return;
	}

	if ($action eq 'login') {
		my $username = $cgi->param('username');
		my $password = $cgi->param('password');

		if (! $username) {
			# TODO ... sane reporting of the error
			# No username specified
			return;
		}

		if (! $password) {
			# TODO ... sane reporting of the error
			# No password specified
			return;
		}

		# Verify the u/p
		my $rows = $sqldb->extract("select password, active, expires_on from user where username = ?", $username);

		if (! $rows || ! $rows->[0]) {
			# TODO ... sane reporting of the error
			# The user does not exist
			return;
		}

		my ($pw, $act, $exp) = @{$rows->[0]};

		if ($pw ne $password) {
			# Password mismatch
			return;
		}

		if (! $act) {
			# Username disabled
			return;
		}

		my $now_dt = time2str('%Y-%m-%d %T', time());

		if ($exp && $exp lt $now_dt) {
			# Username expired
			return;
		}

		# Ok, they've been validated!
		doLogout($self, $username);
		doLogin($self, $username);
	}
}

# ---------------------------------------------------------------------------
# Mark that the named user has logged out
# ---------------------------------------------------------------------------

sub doLogout {
	my ($self, $username) = @_;

	my $sqldb = $self->{sqldb};
	my $cgi = $self->{cgi};

	my $xuser = $sqldb->fetch1("select username from logged_in where username = ?", $username);

	if (! $xuser) {
		# This username is not currently logged in, so nothing to do
		return;
	}

	# Insert a logout record
	my $now = time2str('%Y-%m-%d %T', time());
	my $id_token = $self->{cgi}->cookie($id_cookie_name);

	$sqldb->insert('login_history',
		id => 0,
		is_login => 0,
		username => $username,
		id_token => $id_token,
		created_on => $now,
		ip_address => $ENV{REMOTE_ADDR},
		uri => $ENV{REQUEST_URI},
	);

	# Delete the row from logged_in
	$sqldb->execute("delete from logged_in where username = ?", $username);
}

# ---------------------------------------------------------------------------
# Log which identifier visited where
# ---------------------------------------------------------------------------

sub logIdent {
	my $self = shift;

	my $sqldb = $self->{sqldb};
	my $cgi = $self->{cgi};

	my $id_token = $cgi->cookie($id_cookie_name);

	if ($id_token) {
		my $now = time2str('%Y-%m-%d %T', time());
		my $username = getUserName($self);

		# Remember when this token was last used (so we can purge never-used ones)
		$sqldb->execute("update ident set last_used_on = ? where id_token = ?", $now, $id_token);

		# Log who saw what, when
		$sqldb->insert('access_log',
			id_token => $id_token,
			created_on => $now,
			username => $username,
			ip_address => $ENV{REMOTE_ADDR},
			uri => $ENV{REQUEST_URI},
		);

	}
}

1;
