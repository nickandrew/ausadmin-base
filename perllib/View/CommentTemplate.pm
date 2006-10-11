#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#   A template for an article

package View::CommentTemplate;

use strict;

use base 'Contained';
use Carp qw(carp confess);

# ---------------------------------------------------------------------------
# A CommentTemplate was submitted. What do we do with it?
# ---------------------------------------------------------------------------

sub executeForm {
	my $self = shift;

	my $action = $self->{vars}->{action} || '';

	if ($action eq 'Submit') {
		submitComment($self);
		$self->{submitted} = 1;
		print "Thanks, I submitted it.\n";
	}

	# Otherwise do nothing
}

# ---------------------------------------------------------------------------
# Preview this comment
# ---------------------------------------------------------------------------

sub preview {
	my $self = shift;

	my $subject = $self->{vars}->{subject};
	my $contents = $self->{vars}->{contents};

	if (! $subject || ! $contents) {
		return '';
	}

	my $s = qq{<hr>
<h2>Preview</h2>
Your comment will look something like this:<br>
Subject: $subject<br>
$contents
<hr>
};

	return $s;
}

sub form {
	my $self = shift;

	my $action = $self->{vars}->{action} || '';

	if ($action eq 'Submit') {
		return 'Your new comment was submitted';
	}

	my $include = $self->{container}->getInclude();
	return $include->resolveFile("comment-template.html");
}

sub submitComment {
	my $self = shift;

	my $subject = $self->{vars}->{subject};
	my $contents = $self->{vars}->{contents};

	my $container = $self->{container};
	my $sqldb = $self->getSQLDB();

	$sqldb->insert('comment',
		id => 0,
		article_id => $self->{vars}->{article_id},
		parent_id => undef, # TODO
		title => $subject,
		contents => $contents,
		submitted_by => $self->getUserName(),
		created_on => $container->dateTime(),
	);
}

1;
