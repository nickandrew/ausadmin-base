#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
# An HTML view of recent articles
#
# Methods:
#   new()
#   asHTML()

package View::Articles;

use strict;
use base 'Contained';

use Data::Dumper qw(Dumper);
$Data::Dumper::Indent = 1;

sub new {
	my $class = shift;
	my $self = { @_ };
	bless $self, $class;
	return $self;
}

sub asHTML {
	my $self = shift;

	my $sqldb = $self->getSQLDB();

	my $rows = $sqldb->extract("select id, title, contents, submitted_by, created_on from article order by id desc");

	my @content;
	foreach my $row (@$rows) {
		push(@content, articleHTML($self, $row));
	}

	return join('', @content);
}

sub articleHTML {
	my ($self, $row) = @_;

	my ($id, $title, $contents, $submitted_by, $created_on) = @$row;

	my $s = <<EOF;
<div style="border: solid; border-width: thin">
 <span style="background-color: lime;font-family: sans-serif">($id) $title
  <span style="text-align: right; font-size: smaller">Submitted by $submitted_by on $created_on</span>
 </span>
 <div style="margin-left: 1em; margin-right: 1em; text-align: justify">
 $contents
 </div>
EOF

	# We want to add some controls:
	# - comment
	# - delete article
	# - edit article

	$s .= <<EOF;
<span style="background-color: #e9c0e9; font-size: smaller; border: none">
<form style="display: inline" method="POST">
 <input type="hidden" name="_form" value="Article|$id" />
 <input type="submit" name="action" value="delete" />
</form>
<form style="display: inline" method="POST">
 <input type="hidden" name="_form" value="Article|$id" />
 <input type="hidden" name="article_id" value="$id" />
 <input type="submit" name="action" value="comment" />
</form>
</span>
EOF

	$s .= "</div>\n";

	return $s;
}

1;
