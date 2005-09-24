#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#	An Article is like a news item.

package Article;

use strict;
use base 'Contained';

sub setTitle {
	my ($self, $new_title) = @_;

	$self->{prop}->{title} = $new_title;
}

sub setUserProperty {
	my ($self, $name, $value) = @_;

	my $sqldb = $self->getSQLDB();
	my $id = $self->{id};
	my $username = $self->getUserName();

	$sqldb->execute("delete from article_user_prop where article_id = ? and username = ? and name = ?", $id, $username, $name);

	if (defined $value) {
		$sqldb->insert('article_user_prop',
			article_id => $id,
			username => $self->getUserName(),
			name => $name,
			value => $value,
		);
	}
}

sub getUserProperty {
	my ($self, $name) = @_;

	my $sqldb = $self->getSQLDB();
	my $id = $self->{id};
	my $username = $self->getUserName();

	my $value = $sqldb->fetch1("select value from article_user_prop where article_id = ? and username = ? and name = ?", $id, $username, $name);

	return $value;
}

1;
