#!/usr/bin/perl -w
#	@(#) $Id$
#	vim:sw=4:ts=4:

use strict;

use CGI qw();

# Local modules
use SignControl qw();

print "Content-Type: text/html\n";
print "Expires: 0\n\n";

my $cgi = CGI->new();

my $resp;

eval {
	$resp = processForm($cgi);
};

if ($@) {
	$resp = "<p>processForm died:<br><pre>$@</pre><br>";
}

my $form = htmlForm($cgi);

print <<EOF;
<html>
<head>
<title>Stuff</title>
</head>
<body>
$resp
<br />
$form
</body>
</html>
EOF

exit(0);

# ---------------------------------------------------------------------------
# Form for submitting a control message to be signed
# Arguments:
#    control  (newgroup|rmgroup)
#    args     (typically newsgroup name)
#    message  (text to go in body of output message)
# ---------------------------------------------------------------------------

sub htmlForm {
	my ($cgi) = @_;

	my $args = $cgi->param('args') || '';
	my $message = $cgi->param('message') || '';

	my $html = qq{
<form method="POST">
Control <select name="control">
<option selected>newgroup</option>
<option>rmgroup</option>
</select>
Args <input name="args" size="63" maxlength="63" value="$args"><br />
Accompanying Message<br />
<textarea name="message" rows="20" cols="75">$message</textarea>
<input type="submit" name="submit" value="Submit" />
</form>
};

	return $html;
}

# ---------------------------------------------------------------------------
# Process a submitted form (sign and show the signed message
# Return HTML
# ---------------------------------------------------------------------------

sub processForm {
	my ($cgi) = @_;

	my $submit = $cgi->param('submit');
	my $control = $cgi->param('control');
	my $args = $cgi->param('args');
	my $message = $cgi->param('message');

	if (! $submit) {
		return "No form submitted - submit";
	}

	if (! $control) {
		return "No form submitted - control";
	}

	unless ($control && $control =~ /^(newgroup|rmgroup)$/ && $args && $message) {
		# Nothing here?
		return 'No form submitted';
	}

	# Change CRLF to simply LF from posted form
	$message =~ s/\r\n/\n/g;

	my $headers = {
		Control => "$control $args",
		Path => 'bounce-back',
		From => 'Henrietta K Thomas <>',
		Approved => 'Henrietta',
		'X-Info' => 'ftp://ftp.isc.org/pub/pgpcontrol/README.html' . "\n\t" . 'ftp://ftp.isc.org/pub/pgpcontrol/README',
	};

	my $sc = SignControl->new(
		pgpsigner => 'newsadmin@usenetnews.us',
		id_host => 'junk.com',
		hierarchies => 'us',
		force => {
		},
	);

	my $text = $sc->signMessage($headers, $message);

	return qq{<p>
Your message has been signed, and it appears below:
</p>
<table border="1" cellpadding="0" cellspacing="0">
<tr><td>$text</td></tr>
</table>
};

}

