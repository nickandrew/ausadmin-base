#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:

package View::MainPage;

use strict;
use warnings;

use Date::Format qw(time2str);

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
		$self->{articles} = new View::Articles();
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
# cached. This function is for view objects only.
# ---------------------------------------------------------------------------

sub getObject {
	my ($self, $object_name) = @_;

	# Figure out class and id
	my ($class, $id);
	if ($object_name !~ /^([A-Za-z0-9_]+)(\|(.+))?/) {
		die "Unparseable object name: $object_name";
	}

	my ($class, $id) = ($1, $3);
	$id = '' if (!defined $id);
		
	my $obj = $self->{objects}->{$class}->{$id};
	if ($obj) {
		return $obj;
	}

	# Now instantiate it
	my $classes = {
		Article => 'View::Article',
		ArticleTemplate => 'View::ArticleTemplate',
		Articles => 'View::Articles',
		NewsgroupList => 'View::NewsgroupList',
		LoginBox => 'View::LoginBox',
		ProposalList => 'View::ProposalList',
		RunningVotesList => 'View::RunningVotesList',
	};

	my $perl_class = $classes->{$class};
	if (! $perl_class) {
		# Cannot do it
		die "No class defined for $object_name ($class)";
		return undef;
	}

	eval "use $perl_class";
	if ($@) {
		# Cannot do it
		die "Unable to use $perl_class";
		return undef;
	}

	$obj = $perl_class->new(container => $self, id => $id);
	if (! $obj) {
		# Cannot do it
		die "Unable to instantiate new $perl_class";
		return undef;
	}

	$self->{objects}->{$object_name} = $obj;
	return $obj;
}

# ---------------------------------------------------------------------------
# Return a reference to a VoteList
# ---------------------------------------------------------------------------

sub getVoteList {
	my $self = shift;

	if (! $self->{votelist}) {
		$self->{votelist} = new VoteList(vote_dir => "$ENV{AUSADMIN_HOME}/vote");
	}

	return $self->{votelist};
}

# ---------------------------------------------------------------------------
# Return the current username
# ---------------------------------------------------------------------------

sub getUserName {
	my $self = shift;

	return $self->{cookies}->getUserName() || 'notloggedin';
}

# ---------------------------------------------------------------------------
# Return the current date/time
# ---------------------------------------------------------------------------

sub dateTime {
	my $self = shift;

	return time2str('%Y-%m-%d %T', time());
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
			$obj->executeForm();
		}
	}
}

# ---------------------------------------------------------------------------
# Callback function for the use of the template engine
# ---------------------------------------------------------------------------

sub viewFunction {
	my ($self, $include, $object_name, $function_name, @args) = @_;

	if ($object_name && $object_name ne 'self') {
		my $obj = getObject($self, $object_name);
		if (! $obj) {
			return "<b>No object $object_name</b>";
		}
		# Call into the object
		return $obj->$function_name(@args);
	}

	if ($function_name eq 'contentFile') {
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

	return "<b>Unable to do function: $function_name</b>";
}

sub getSQLDB {
	my $self = shift;

	return $self->{sqldb};
}

1;
