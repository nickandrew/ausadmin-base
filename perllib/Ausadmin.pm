#!/usr/bin/perl
#	@(#) misc.pli - miscellaneous functions
# $Source$
# $Revision$
# $Date$

=head1 NAME

Ausadmin - misc functions class

=head1 SYNOPSIS

 use Ausadmin;
 $line = Ausadmin::read1line($path);
 $string = Ausadmin::readfile($path);
 @lines = Ausadmin::format_para($line)
 @lines = Ausadmin::centred_text(@lines)

=head1 DESCRIPTION

This package provides some useful file I/O functions

=cut


package Ausadmin;

sub read1line {
	my($path) = @_;
	my($line);
	if (!open(F, $path)) {
		return "";
	}
	chop($line = <F>);
	close(F);
	return $line;
}

sub readfile {
	my($path) = @_;
	my($line);
	if (!open(F, $path)) {
		return "";
	}
	while (<F>) {
		$line .= $_;
	}
	close(F);
	return $line;
}

# Join all lines into one and split them into a paragraph.

sub format_para {
	my($line) = @_;
	my($rest);
	my($last_space);
	my(@result);

	# Format as a paragraph, max 72 chars
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

1;
