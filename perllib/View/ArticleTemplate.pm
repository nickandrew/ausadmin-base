#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#   A template for an article

package View::ArticleTemplate;

use strict;

use base 'Contained';
use Carp qw(carp confess);

sub xnew {
	my $class = shift;
	my $self = { };
	bless $self, $class;
	return $self;
}

sub xsetVars {
	my ($self, $hr) = @_;

	my $vars = $self->{vars} = { };
	foreach my $k (keys %$hr) {
		$vars->{$k} = $hr->{$k};
	}
}

sub xresolveVar {
	my ($self, $name) = @_;

	my $value = $self->{vars}->{$name};

	if ($name eq 'article_subject') {
		return ucfirst($value);
	}
	elsif ($name eq 'article_contents') {
		$value =~ s/^/> /mg;
	}

	if (!defined $value) {
		return '';
	}

	return $value;
}

sub preview {
	my $self = shift;

	my $subject = $self->{vars}->{article_subject};
	my $contents = $self->{vars}->{article_contents};

	if (! $subject || ! $contents) {
		return '';
	}

	my $s = qq{<hr>
<h2>Preview</h2>
Your article will look something like this:<br>
Subject: $subject<br>
$contents
};

	return $s;
}

sub form {
	my $self = shift;

	my $include = $self->{container}->getInclude();
	return $include->resolveFile("article-template.html");
}

1;
