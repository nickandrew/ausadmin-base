#!/usr/bin/perl -w
#	@(#) $Header$
#	vim:sw=4:ts=4:
#
#  Email sending module
#
#  $x = Ausadmin::Email->new(
#      template => 'registration.email',
#  );
#
#  $x->send($hashref);

package Ausadmin::Email;

use IO::File qw(O_RDONLY);
# use IPC::Open2 qw();
use Net::SMTP qw();

use Ausadmin qw();

sub new {
	my $class = shift;
	my $self = { @_ };

	die "Need template" if (! $self->{template});

	my $data_path = Ausadmin::dataPath();

	my $path = "$data_path/templates/$self->{template}";
	if (! -f $path) {
		die "No file: $path";
	}

	my $fh = IO::File->new($path, O_RDONLY());
	if (! $fh) {
		die "Unable to open $path for read: $!";
	}
	my $template = join('', <$fh>);
	$fh->close();

	$self->{template_text} = $template;

	bless $self, $class;

	return $self;
}

sub resolve_template {
	my($text, $hr) = @_;

	$text =~ s/\$([A-Z0-9_]+)\$/$hr->{$1}/eg;

	# FIXME ... the following code probably does nothing
	if ($text =~ /\$([A-Z0-9_]+)\$/) {
		die "Missing substitution value: $1";
	}

	return $text;
}

sub send {
	my $self = shift;
	my $recipients = shift;
	my $values = shift;

	if (! ref($recipients)) {
		$recipients = [ $recipients ];
	}

	my $text = resolve_template($self->{template_text}, $values);

	my $smtp = Net::SMTP->new(Ausadmin::config('smtp_server'));

	my $mail_from = Ausadmin::config('mail_from');

	foreach my $recip (@$recipients) {
		$smtp->mail($mail_from);
		$smtp->to($recip);
		$smtp->data();
		$smtp->datasend($text);
		$smtp->dataend();
	}

	$smtp->quit();
}

1;
