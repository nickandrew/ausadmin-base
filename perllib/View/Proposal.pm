#!/usr/bin/perl
#	@(#) $Header$

package View::Proposal;

sub insideBody {
	my $vote = shift;

	my $rfd_text = $vote->read_file("rfd");

	my @contents;

	push(@contents, <<EOF);
<table width="600" cellpadding="0" cellspacing="0" border="0">
 <tr>
EOF

	push(@contents, View::MainPage::leftColumn());

	my $s;

	$s = qq~
<td valign="top">
<pre>
@$rfd_text
</pre>
</td valign="top">
~;

	push(@contents, $s);

	push(@contents, <<EOF);
 </tr>
</table>
EOF

	return \@contents;
}

1;
