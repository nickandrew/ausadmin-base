#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#   A template for an article

package View::ArticleTemplate;

use strict;

use base 'Contained';
use Carp qw(carp confess);

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

	my $action = $self->{vars}->{action} || '';

	if ($action eq 'Submit') {
		submitArticle($self);
		return 'Thanks, I submitted it';
	}

	my $include = $self->{container}->getInclude();
	return $include->resolveFile("article-template.html");
}

sub submitArticle {
	my $self = shift;

	my $subject = $self->{vars}->{article_subject};
	my $contents = $self->{vars}->{article_contents};

	my $container = $self->{container};
	my $sqldb = $container->{sqldb};

	$sqldb->insert('article',
		id => 0,
		proposal_id => undef,
		title => $subject,
		contents => $contents,
		submitted_by => $container->getUserName(),
		created_on => $container->dateTime(),
	);
}

1;
