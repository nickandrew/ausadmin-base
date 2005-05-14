#!/usr/bin/perl
#	@(#) Ausadmin.pm - miscellaneous ausadmin specific functions

# $Id$
# $Source$
# $Revision$
# $Date$

=head1 NAME

Ausadmin - misc functions class

=head1 SYNOPSIS

 use Ausadmin;
 $line = Ausadmin::read1line($path);
 $string = Ausadmin::readfile($path);
 $ref = Ausadmin::read_keyed_file($path);
 $ref = Ausadmin::read_multi_keyed_file($path, $keyname);
 $ref = Ausadmin::read_list_keyed_file($path);
 @lines = Ausadmin::format_para($line)
 @lines = Ausadmin::centred_text(@lines)
 Ausadmin::print_header(\%headers, [$file_handle] )
 $string = Ausadmin::make_header(\%headers)
 $yyyymmdd = Ausadmin::today()

 $sign_email = Ausadmin::pgp_signer()

 $value = Ausadmin::config($keyname);

=head1 DESCRIPTION

This package provides some useful file I/O functions

=head2 Ausadmin::print_header(\%headers)

Update the default headers (which are hardcoded in this class) with
the caller-supplied headers and output, to the current selected device,
a message header block.

=head2 $string = Ausadmin::make_header(\%headers)

Update the default headers (which are hardcoded in this class) with
the caller-supplied headers and return a string containing all the
headers and ending in \n\n.

=head2 Ausadmin::read_keyed_file($path)

Open B<$path> and read the file as a series of lines of the form:

 Keyword: value

and return a reference to a hash containing the keywords and values.

=head2 Ausadmin::read_multi_keyed_file($path, $keyname)

As for read_keyed_file(), except that the file contains multiple
paragraphs (separated by one or more empty lines)
each containing one or more (keyword,value) pairs. Return a
reference to a hash where the key is the value of the B<$keyname>
keyword in each paragraph, and the value is a reference
to a hash as for read_keyed_file(). If that makes sense.

=head2 Ausadmin::read_list_keyed_file($path)

As for read_keyed_file(), except that the file contains multiple
paragraphs (separated by one or more empty lines) each
containing one or more (keyword,value) pairs. Return a reference
to a list where each item in the list is a hash reference to
each paragraph's parsed contents.

=head2 Ausadmin::pgp_signer()

Return the string (usually an email address) which identifies
the GPG key to use for signing articles.

=head2 Ausadmin::sqldb()

Return a reference to an instance of SQLdb (same instance every
time)

=cut


package Ausadmin;

use SQLdb qw();

%Ausadmin::ph_defaults = (
	'Newsgroups' => 'aus.general,aus.net.news',
	'From' => 'ausadmin <ausadmin@aus.news-admin.org>',
	'Organization' => 'aus.* newsgroups administration, see http://aus.news-admin.org/',
	'X-PGPKey' => 'at http://aus.news-admin.org/ausadmin.asc',
	'Followup-To' => 'aus.net.news'
);

$Ausadmin::pgp_signer_default = 'ausadmin@aus.news-admin.org';

my $sqldb;

my $config_statics = {
	cookie_domain => '127.0.0.1',
	uri_prefix => '/ausadmin',
	db_name => 'ausadmin',
	db_user => 'ausadmin',
	db_password => undef,
};

# ---------------------------------------------------------------------------
# Return a reference to our database
# ---------------------------------------------------------------------------

sub sqldb {
	if (! $sqldb) {
		$sqldb = SQLdb->new(
			database => $config_statics->{db_name},
			user => $config_statics->{db_user},
			password => $config_statics->{db_password},
		);
	}

	return $sqldb;
}


# ---------------------------------------------------------------------------
# Read 1 line from a file
# ---------------------------------------------------------------------------

sub read1line {
	my $path = shift;
	my $line;
	if (!open(AU_F, $path)) {
		return "";
	}
	chomp($line = <AU_F>);
	close(AU_F);
	return $line;
}

sub readfile {
	my $path = shift;
	my $line;
	if (!open(AU_F, $path)) {
		return "";
	}
	while (<AU_F>) {
		$line .= $_;
	}
	close(AU_F);
	return $line;
}

sub read_keyed_file {
	my $path = shift;
	my $ref;
	if (!open(AU_F, $path)) {
		return undef;
	}
	while (<AU_F>) {
		chomp;
		if (/^([^:]+): (.*)/) {
			$ref->{$1} = $2;
		}
	}
	close(AU_F);
	return $ref;
}

sub read_multi_keyed_file {
	my $path = shift;
	my $keyname = shift;

	my $ref;
	my $hash;
	my $line = 0;

	if (!open(AU_F, $path)) {
		return undef;
	}
	while (<AU_F>) {
		chomp;
		$line++;

		if ($_ eq '') {
			if ($ref) {
				# This is the end of a group, find its key
				if (!exists $ref->{$keyname}) {
					die "Ausadmin::read_multi_keyed_file: No keyword $keyname in $path (line $line)";
				}

				$hash->{$ref->{$keyname}} = $ref;
				undef $ref;
			}
			next;
		}

		if (/^([^:]+): (.*)/) {
			$ref->{$1} = $2;
		}
	}
	close(AU_F);

	if ($ref) {
		# This is the end of a group, find its key
		if (!exists $ref->{$keyname}) {
			die "Ausadmin::read_multi_keyed_file: No keyword $keyname in $path (line $line)";
		}

		$hash->{$ref->{$keyname}} = $ref;
	}

	return $hash;
}

sub read_list_keyed_file {
	my $path = shift;

	my $ref;
	my $list;
	my $line = 0;

	if (!open(AU_F, $path)) {
		return undef;
	}
	while (<AU_F>) {
		chomp;
		$line++;

		if ($_ eq '') {
			# This is the end of a group, add it to the list
			if ($ref) {
				push(@$list, $ref);
				undef $ref;
			}
			next;
		}

		if (/^([^:]+): (.*)/) {
			$ref->{$1} = $2;
		}
	}
	close(AU_F);

	if ($ref) {
		push(@$list, $ref);
	}

	return $list;
}

# Join all lines into one and split them into a paragraph.

sub format_para {
	my($line) = @_;
	my($rest);
	my($last_space);
	my(@result);

	# Format as a paragraph, max 72 chars
#	$line =~ s/\n/ /g;
	$line =~ tr/\n/ /;
	while (length($line) > 72) {
		$last_space = rindex($line, ' ', 72);
		if ($last_space > 0) {
			my $first = substr($line, 0, $last_space);
			push(@result, $first);
			$rest = substr($line, $last_space + 1);
			$line = $rest;
		}
	}
	if ($line ne "") {
		push(@result, $line);
	}

	return @result;
}

sub centred_text {
	my @output;
	my $width = 78;

	foreach my $line (@_) {
		chomp($line);
		if (length $line >= $width) {
			push(@output, "$line\n");
		} else {
			my $c = ($width - length $line)/2;
			push(@output, sprintf("%*s%s\n", $c, '', $line));
		}
	}

	return @output;
}

sub make_header {
	my($hashref) = @_;
	my %headers = %$hashref;

	foreach my $header (keys %Ausadmin::ph_defaults) {
		if (!exists $headers{$header}) {
			$headers{$header} = $Ausadmin::ph_defaults{$header};
		}
	}

	my $s;

	foreach my $header (keys %headers) {
		if ($headers{$header} ne "") {
			$s .= "$header: $headers{$header}\n";
		}
	}

	$s .= "\n";

	return $s;
}

sub print_header {
	my $header_hr = shift;
	my $fh = shift;

	if (defined $fh) {
		print $fh Ausadmin::make_header($header_hr);
	} else {
		print Ausadmin::make_header($header_hr);
	}
}

sub today {
	my($sec,$min,$hour,$mday,$mon,$year) = localtime(time());
	$mon++; $year += 1900;
	my $yyyymmdd = sprintf "%d-%02d-%02d", $year,$mon,$mday;

	return $yyyymmdd;
}

=pod
	$string = email_obscure($string)

Obscure any Email address in the string (change @ to " at ").

=cut

sub email_obscure {
	my $string = shift;

	$string =~ s/\@/ at /g;

	return $string;
}

sub pgp_signer {
	return $Ausadmin::pgp_signer_default;
}

sub resolve_template {
	my($text, $hr) = @_;

	$text =~ s/\$([A-Z0-9]+)\$/$hr->{$1}/eg;

	return $text;
}

sub sendmail_template {
	my($file, $hr, @recipients) = @_;

	open(SMTP, "<$file") || die "Unable to open $file for read: $!";
	my $text = join('', <SMTP>);
	close(SMTP);

	$text = resolve_template($text, $hr);

	my $recip = join(' ', @recipients);
	$recip =~ s/[^A-Z0-9a-z.\@_-]+//g;

	$ENV{MAILHOST} = 'aus.news-admin.org';
	$ENV{QMAILUSER} = 'ausadmin';

	open(SM, "|/usr/sbin/sendmail $recip") || die "Unable to open pipe to sendmail: $!";
	print SM $text;
	close(SM);
}

# ---------------------------------------------------------------------------
# Return the value of a named configuration parameter
# ---------------------------------------------------------------------------

sub config {
	my $keyname = shift;

	my $value = $config_statics->{$keyname};
	if (defined $value) {
		return $value;
	}

	return undef;
}

1;
