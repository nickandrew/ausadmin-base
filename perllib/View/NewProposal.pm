#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#	A "New Proposal"

package View::NewProposal;

sub new {
	my $class = shift;
	my $cookies = shift;

	my $self = {
		cookies => $cookies,
	};

	bless $self, $class;

	return $self;
}

# ---------------------------------------------------------------------------
# Return HTML or a list of HTML, representing the content of this object
# ---------------------------------------------------------------------------

sub asHTML {
	my $self = shift;

	return qq{
<p>
Enter Details of your proposal here.
</p>
<form method="POST">
<table border="1" cellpadding="3" cellspacing="0">
<tr>
 <td>New newsgroup name</td>
 <td><input name="newsgroup" size="33" maxlength="33"></td>
</tr>

<tr>
 <td>1-line Description</td>
 <td><input name="ngline" size="60" maxlength="60"></td>
</tr>

<tr>
 <td>Rationale</td>
 <td>
   <p>
   Provide a brief description of the reasons you believe this new
   newsgroup should be created. At a minimum, you should attempt to
   address the following frequent questions:
   </p>
   <ul>
    <li>Is USENET discussion occurring on this topic already?</li>
    <li>How much?</li>
    <li>What similar newsgroups already exist, and why are they
    inappropriate for discussing this topic?</li>
   </ul>
  <textarea name="rationale" rows="15" cols="80">
 </td>
</tr>
