#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#	Login/Logout Box

package LoginBox;

use strict;

use Ausadmin qw();

use base 'Contained';
use Carp qw(carp confess);

# ---------------------------------------------------------------------------
# Return a 'username/password/register' box
# ---------------------------------------------------------------------------

sub html {
	my $self = shift;
	my $cookies = $self->{container}->{cookies};

	my $uri_prefix = Ausadmin::config('uri_prefix');
	my $username = $cookies->getUserName();

	if ($username) {
		return qq{
<form method="POST">
<input type="hidden" name="action" value="logout" />
<table border="1" cellpadding="1" cellspacing="0">
<tr>
 <td>Logged in as $username</td>
</tr>

<tr>
 <td><input type="submit" value="Logout" /></td>
</tr>
</table>
</form>
};
	}

	# They are not logged in.

	return qq{
<form method="POST">
<input type="hidden" name="action" value="login">
<table border="1" cellpadding="1" cellspacing="0">
<tr>
 <td colspan="3">Please login or register</td>
</tr>

<tr>
 <td>Username</td>
 <td colspan="2"><input name="username" maxlength="16"></td>
</tr>

<tr>
 <td>Password</td>
 <td><input name="password" type="password" size="10" maxlength="16"></td>
 <td><input type="submit" value="Go"></td>
</tr>

<tr>
 <td colspan="3" align="center" >
  <a href="$uri_prefix/register.cgi">Register</a> /
  <a href="$uri_prefix/lostpass.cgi">Lost Password</a>
</tr>

</table>
</form>
};

};

1;
