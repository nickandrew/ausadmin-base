#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:

package View::ProposalEdit;

use strict;
use warnings;

use Ausadmin::Proposal qw();

sub new {
	my ($class, $sqldb, $cgi) = @_;

	die "Need sqldb" if (! $sqldb);
	die "Need cgi" if (! $cgi);

	my $self = {
		sqldb => $sqldb,
		cgi => $cgi,
	};

	bless $self, $class;
	return $self;
}

sub asHTML {
	my ($self) = @_;

	my $text = proposalInputForm($self);

	return $text;
}

# ---------------------------------------------------------------------------
# Output HTML to show an existing proposal
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Output a form to input a proposal
# ---------------------------------------------------------------------------

sub proposalInputForm {
	my $self = shift;

	my $proposal_id = '';
	my $group_name = 'aus.';
	my $newsgroups_line = '';
	my $rationale = '';
	my $charter = qq{
aus.animals.frogs is for the discussion of FROGS AND LIZARDS. Examples of
on-topic discussions include:
<ul>
<li>FROG LIFECYCLE</li>
<li>FROG BREEDING HABITS</li>
<li>PET FROGS AND PET TADPOLES</li>
</ul>
<p>
Off-topic posts, such as the following subjects, are discouraged:
<ul>
<li>SALAMANDERS AND OTHER FISH</li>
</ul>
<p>
What is not acceptable: & and "
</p>

<li>HTML posting</li>
<li>Binaries (post a URL instead)</li>
<li>Crossposting to more than 3 other newsgroups</li>
<li>Commercial advertisements more frequently than one per month</li>
<li>For-Sale advertisements, unless [FS] appears in the subject</li>
<li>Auction advertisements</li>
<li>Flaming and ad-hominem attacks</li>
<li>Spam and chain letters</li>
};

	# Make it safe to embed in HTML
    $group_name = escapeAttributeValue($group_name);
    $rationale = htmlEscape($rationale);
    $charter = htmlEscape($charter);

	my $html = qq{
<form method="POST">
 <input type="hidden" name="form" value="View::ProposalEdit" />
 <input type="hidden" name="proposal_id" value="$proposal_id" />
 <table border="1" cellpadding="1" cellspacing="0">
  <tr>
   <td>
    Proposal $proposal_id
   </td>
  </tr>
  <tr>
   <td>Newsgroup name:
    <input name="group_name" size="64" maxlength="64" value="$group_name" />
   </td>
  </tr>
  <tr>
   <td>Summary line:
    <input name="newsgroups_line" size="80" maxlength="80" value="$newsgroups_line" />
   </td>
  </tr>
  <tr>
   <td>Rationale:
    <textarea name="rationale" rows="10" cols="80">$rationale</textarea>
   </td>
  </tr>
  <tr>
   <td>Charter:
    <textarea name="charter" rows="10" cols="80">$charter</textarea>
   </td>
  </tr>
  <tr>
   <td>
    <input type="submit" name="action" value="Save" />
    <input type="submit" name="action" value="Discard" />
   </td>
  </tr>
 </table>
</form>
};

	return $html;
}

# ---------------------------------------------------------------------------
# Make it safe to embed inside an HTML attribute
# ---------------------------------------------------------------------------

sub escapeAttributeValue {
	my $string = shift;

	$string =~ s/&/&amp;/g;
	$string =~ s/"/&quot;/g;

	return $string;
}

# ---------------------------------------------------------------------------
# Make it safe to embed inside generic HTML
# ---------------------------------------------------------------------------

sub htmlEscape {
	my $string = shift;

	$string =~ s/&/&amp;/g;
	$string =~ s/"/&quot;/g;
	$string =~ s/</&lt;/g;
	$string =~ s/>/&gt;/g;

	return $string;
}

# ---------------------------------------------------------------------------
# Process this form
# ---------------------------------------------------------------------------

sub process {
	my $self = shift;

	my $cgi = $self->{cgi};
	my $sqldb = $self->{sqldb};
	my $form = $cgi->param('form') || '';

	if ($form eq 'View::ProposalEdit') {
		# Save it, etc
		my $proposal_id = $cgi->param('proposal_id') || 0;
		my $group_name = $cgi->param('group_name');
		my $newsgroups_line = $cgi->param('newsgroups_line');
		my $rationale = $cgi->param('rationale');
		my $charter = $cgi->param('charter');

		if ($proposal_id) {
			# Update an existing one
			die "Not yet coded - update an existing proposal";
		}

		# Insert a new one

		# TODO ... first validate the data

		# Now save it to the database
		my $proposal_obj = Ausadmin::Proposal->new($sqldb, {
			group_name => $group_name,
			newsgroups_line => $newsgroups_line,
			rationale => $rationale,
			charter => $charter,
		} );

		$proposal_id = $proposal_obj->g('id');

		$self->{proposal_id} = $proposal_id;
	}
}

1;
