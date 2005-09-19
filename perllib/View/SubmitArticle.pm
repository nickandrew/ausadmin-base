#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
# Submit an article
#
# Methods:
#   new()
#   asHTML()

package View::SubmitArticle;

use strict;

use Include qw();

# ---------------------------------------------------------------------------
# Likely parameters:
#    vars
# ---------------------------------------------------------------------------

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;
	return $self;
}

sub asHTML {
	my $self = shift;

	my $include = new Include(vars => $self->{vars});

	return $include->resolveFile("article-template.html");
}

sub preview {
	my $self = shift;

	my $include = $self->{container}->getInclude();
	return $include->resolveFile("article-template.html");
}

1;
