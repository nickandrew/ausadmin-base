#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:

package View::MainPage;

use strict;
use warnings;

use VoteList qw();
use Include qw();

# ---------------------------------------------------------------------------
# Create a new instance of this class.
# ---------------------------------------------------------------------------

sub new {
	my $class = shift;
	my $self = { @_ };

	$self->{objects} = { };

	bless $self, $class;
	return $self;
}

# ---------------------------------------------------------------------------
# We are a container. Add an object to our container.
# Later we might like to make the name a property of the object.
# ---------------------------------------------------------------------------

sub addObject {
	my ($self, $obj_name, $obj) = @_;

	if (exists $self->{objects}->{$obj_name}) {
		die "Already exists: view $obj_name";
	}

	$self->{objects}->{$obj_name} = $obj;
}

sub proposalList {
	my $self = shift;
	my $votelist = shift;
	my @contents;

	my @proposals = $votelist->voteList('activeProposals');

	if (! @proposals) {
		return '';
	}

	my $uri_prefix = $self->{vars}->{URI_PREFIX};

	push(@contents, <<EOF);
<!-- start of proposals -->
<p>
<b>Proposals:</b><br />
EOF

	foreach my $v (@proposals) {
		my $p = $v->getName();
		my $s = "&nbsp;&nbsp;<a href=\"$uri_prefix/proposal.cgi?proposal=$p\">$p</a><br />\n";
		push(@contents, $s);
	}

	push(@contents, <<EOF);
</p>
<!-- end of proposals -->
EOF
	return join('', @contents);
}

sub runningVotesList {
	my $self = shift;
	my $votelist = shift;

	my @contents;

	my @runningvotes = $votelist->voteList('runningVotes');

	if (! @runningvotes) {
		return '';
	}

	push(@contents, <<EOF);
<!-- start of runningvotes -->
<p>
<b>Votes&nbsp;running:</b><br />
EOF

	my $now = time();

	foreach my $v (@runningvotes) {
		my $p = $v->getName();
		my $endtime = $v->get_end_time();

		if ($endtime < $now) {
			# Ignore it completely
			next;
		}

		my $ed = int(($endtime - $now)/86400);
		my $eh = int(($endtime - $now)/3600);
		my $em = int(($endtime - $now)/60);
		my $es = ($endtime - $now);

		my $ends = "$es seconds";
		$ends = "$em minutes" if ($em > 1);
		$ends = "$eh hours" if ($eh > 1);
		$ends = "$ed days" if ($ed > 1);

		my $s = "&nbsp;&nbsp;<a href=\"/proposal.cgi?proposal=$p\">$p (ends in $ends)</a><br />\n";
		push(@contents, $s);
	}

	push(@contents, <<EOF);
</p>
<!-- end of runningvotes -->
EOF

	return join('', @contents);
}

sub newsgroupList {
	my $self = shift;

	my @contents;

	# Return an array of newsgroup names
	my @newsgrouplist = Newsgroup::list_newsgroups(datadir => "$ENV{AUSADMIN_DATA}");

	if (!@newsgrouplist) {
		return '';
	}

	my $uri_prefix = $self->{vars}->{URI_PREFIX};

	push(@contents, <<EOF);
<p>
<b>Newsgroups:</b><br />
EOF

	foreach my $g (@newsgrouplist) {
		my $s = qq{&nbsp;&nbsp;<a href="$uri_prefix/groupinfo.cgi/$g">$g</a><br />\n};
		push(@contents, $s);
	}

	push(@contents, <<EOF);
</p>
EOF
	return join('', @contents);
}

sub proposalContents {
	my $self = shift;

	my $vote = $self->{vote};

	my $rfd_text = $vote->read_file("rfd");

	return qq{<pre>@$rfd_text</pre>};
}

# ---------------------------------------------------------------------------
# News items
# ---------------------------------------------------------------------------

sub news {
	my $self = shift;

	if (! $self->{articles}) {
		require View::Articles;
		$self->{newsitems} = new View::Articles();
	}

	my $ni = $self->{articles};
	if (! $ni) {
		return "The article section is not currently working";
	}

	return $ni->asHTML();
}

# ---------------------------------------------------------------------------
# Submit article
# ---------------------------------------------------------------------------

sub submitArticle {
	my $self = shift;

	if (! $self->{submit_article}) {
		require View::SubmitArticle;
		$self->{submit_article} = new View::SubmitArticle(vars => $self->{vars});
	}

	my $sa = $self->{submit_article};
	if (! $sa) {
		return "Article submission is not currently working";
	}

	return $sa->asHTML();
}

# ---------------------------------------------------------------------------
# Instantiate an object of the appropriate type, or return one we have
# cached.
# ---------------------------------------------------------------------------

sub getObject {
	my ($self, $object_name) = @_;

	my $obj = $self->{objects}->{$object_name};
	if ($obj) {
		return $obj;
	}

	# Now instantiate it
	my $classes = {
		articleTemplate => 'ArticleTemplate',
		loginBox => 'LoginBox',
	};

	my $class = $classes->{$object_name};
	if (! $class) {
		# Cannot do it
		return undef;
	}

	eval "use $class";
	if ($@) {
		# Cannot do it
		return undef;
	}

	$obj = $class->new(container => $self);
	if (! $obj) {
		# Cannot do it
		return undef;
	}

	$self->{objects}->{$object_name} = $obj;
	return $obj;
}

# ---------------------------------------------------------------------------
# Set a reference to the Include object
# ---------------------------------------------------------------------------

sub setInclude {
	my ($self, $include) = @_;

	$self->{include} = $include;
}

sub getInclude {
	my $self = shift;

	return $self->{include};
}

# ---------------------------------------------------------------------------
# Get CGI parameters.
# That means instantiating objects to hold/process form contents
# ---------------------------------------------------------------------------

sub getCGIParameters {
	my ($self, $cgi) = @_;

	my $form = $cgi->param('_form') || '';

	my $hr = { };
	my @names = $cgi->param();
	foreach (@names) {
		next if ($_ eq '_form');
		$hr->{$_} = $cgi->param($_);
	}

	if ($form) {
		my $obj = $self->getObject($form);
		if ($obj) {
			$obj->setVars(%$hr);
		}
	}
}

# ---------------------------------------------------------------------------
# Callback function for the use of the template engine
# ---------------------------------------------------------------------------

sub viewFunction {
	my ($self, $include, $object_name, $function_name, @args) = @_;

	if ($object_name) {
		my $obj = getObject($self, $object_name);
		if (! $obj) {
			return "<b>No object $object_name</b>";
		}
		# Call into the object
		return $obj->$function_name(@args);
	}

	if ($function_name eq 'loginBox') {
		my @contents;
		push(@contents, $self->loginBox($self->{cookies}));
		return join('', @contents);
	}
	elsif ($function_name eq 'proposalList') {
		my @contents;
		my $votelist = new VoteList(vote_dir => "$ENV{AUSADMIN_HOME}/vote");
		push(@contents, $self->proposalList($votelist));
		return join('', @contents);
	}
	elsif ($function_name eq 'runningVotesList') {
		my @contents;
		my $votelist = new VoteList(vote_dir => "$ENV{AUSADMIN_HOME}/vote");
		push(@contents, $self->runningVotesList($votelist));
		return join('', @contents);
	}
	elsif ($function_name eq 'newsgroupList') {
		my @contents;
		push(@contents, $self->newsgroupList());
		return join('', @contents);
	}
	elsif ($function_name eq 'contentFile') {
		my $string = $include->resolveFile($self->{content});
		if (!defined $string) {
			return "<b>No file $self->{content}</b>";
		}
		return $string;
	}
	elsif ($function_name eq 'proposalContents') {
		my $string = $self->proposalContents();
		return $string;
	}
	elsif ($function_name eq 'news') {
		my $string = $self->news();
		return $string;
	}

	return "<b>Unable to do function: $function_name</b>";
}

1;
