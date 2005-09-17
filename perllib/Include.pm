#!/usr/bin/perl
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#	Include a file into our output

=head1 NAME

Include - template resolution class

=head1 SYNOPSIS

 $i = new Include(vars => {
 	our_name => 'Cyberdyne systems',
	...
 });

 print $i->resolveFile("default.html");

=cut

package Include;

use strict;

use Carp qw(confess);
use IO::File qw(O_RDONLY O_WRONLY O_APPEND O_CREAT O_EXCL);

# ---------------------------------------------------------------------------
# Instantiate a new Include.
# Possible arguments:
#    vars => { ... }      Variables to be substituted
# ---------------------------------------------------------------------------

sub new {
	my $class = shift;

	my $self = { @_ };
	bless $self, $class;
	return $self;
}

# ---------------------------------------------------------------------------
# This function is obsolete. Should be only used internally to this module.
# ---------------------------------------------------------------------------

sub html {
	my $file = shift;

	my $path = "$ENV{AUSADMIN_DATA}/Html/$file";

	if (!-f $path || ! -r _) {
		$path = "$ENV{AUSADMIN_WEB}/Html/$file";
	}

	if (!-f $path || ! -r _) {
		return undef;
	}

	my $fh = new IO::File($path, O_RDONLY);
	die("Unable to open $path : $!") if (!defined $fh);

	my @lines = <$fh>;

	$fh->close();

	return \@lines;
}

# ---------------------------------------------------------------------------
# Recursively resolve a template.
# Return answer as a string (HTML string, I suppose)
# ---------------------------------------------------------------------------

sub resolveFile {
	my ($self, $filename) = @_;

	if (! $self) {
		confess "Need self";
	}

	# Grab the contents
	my $lines = html($filename);
	if (! $lines) {
		return undef;
	}

	my $string = join('', @$lines);

	if (!defined $string) {
		confess "String is undefined";
	}

	# Identify and resolve markers in those lines
	# Each marker looks like {{COMMAND|data|data,...}}
	# The returned string must not contain any markers.
	$string =~ s/{{(\w+)([^}]+)}}/resolveMarker($self,$1,$2)/eg;

	return $string;
}

# ---------------------------------------------------------------------------
# Recursively resolve the content of a marker
# The returned string must not contain any markers.
# ---------------------------------------------------------------------------

sub resolveMarker {
	my ($self, $command, $data) = @_;

	my @args = split(/\|/, $data);
	shift @args; # First one will be empty

	if ($command eq 'uc') {
		my $result = join(' ', @args);
		return uc($result);
	}
	elsif ($command eq 'lc') {
		my $result = join(' ', @args);
		return lc($result);
	}
	elsif ($command eq 'FILE') {
		my $filename = $args[0];
		my $result = resolveFile($self, $filename);
		if (! $result) {
			return "<b>Nothing back from $filename</b>";
		}
		return $result;
	}
	elsif ($command eq 'A') {
		# A|filename|description
		return qq{<a href="$ENV{SCRIPT_NAME}/$args[0]">$args[1]</a>};
	}
	elsif ($command eq 'VAR') {
		# VAR|variable-name
		my $name = $args[0];
		my $value;
		if ($name =~ /^(.+)\.(.+)/) {
			# Grab a value from inside an object
			my ($obj_name, $name) = ($1,$2);
			my $obj = $self->{view}->getObject($obj_name);
			if (! $obj || !ref($obj)) {
				$value = "Huh? $obj_name/$name";
			} else {
				$value = $obj->getVar($name);
			}
		} else {
			$value = $self->{vars}->{$args[0]};
		}
		$value = '' if (!defined $value);
		return $value;
	}
	elsif ($command eq 'VIEW') {
		# VIEW|object-name|function-name|args
		# VIEW|function-name
		my $view = $self->{view};
		if (! $view) {
			return "<b>Cannot view @args - no view</b>";
		}

		my $value;
		my $object_name = '';
		if ($args[1]) {
			$object_name = shift @args;
			$value = $view->viewFunction($self, $object_name, @args);
		} else {
			$value = $view->viewFunction($self, undef, @args);
		}

		if (!defined $value) {
			return "<b>Nothing back from VIEW $object_name @args</b>";
		}
		return $value;
	}
	elsif ($command eq 'COMMENT') {
		# COMMENT|whatever
		return '';
	}
	else {
		return "<b>Unresolved marker: $command</b>";
	}
}


1;
