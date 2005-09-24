#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#	A view of an Article

package View::Article;

use base 'Contained';

use Article qw();

# ---------------------------------------------------------------------------
# This object needs to process a form submission of some kind (probably POST).
# Should it return HTML? Or return a result into something which can be
# read later?
# ---------------------------------------------------------------------------

sub executeForm {
	my $self = shift;

	my $action = $self->{vars}->{action};
	my $id = $self->{id};
	my $sqldb = $self->getSQLDB();
	my $art = new Article(id => $id, container => $self->{container});
	my $value = $art->getUserProperty('deleted');

	print "<pre>\n";
	print "Action was $action on $id (deleted value was $value)\n";
	print "</pre>\n";

	if ($action eq 'delete') {
		$art->setUserProperty('deleted', 1);
	}
}

1;
