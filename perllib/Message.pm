#	@(#) Message.pm - class for an email message

=head1 NAME

Message.pm - class for an email message

=head1 SYNOPSIS

	use Message;
	my $m = new Message();
	$m->parse_file($filename);
	$m->parse_string($string);

=head1 DESCRIPTION

Use this to read and parse an email message - determine the voting
instructions (if any) and establish information identifying the source
of the message.

=cut

package Message;

sub new {
	my $class = shift;
	my $self = { };
	bless $self, $class;

	return $self;
}

sub parse_string {
	my $self = shift;
	my $string = shift;

	$self->{data} = $string;

	$self->parse();
}

sub parse_file {
	my $self = shift;
	my $path = shift;

	if (!open(F, "<$path")) {
		die "Unable to open $path for read: $!";
	}

	my $string;

	while (<F>) {
		$string .= $_;
	}

	close(F);

	$self->parse_string($string);

	return 1;
}

sub parse {
	my $self = shift;

	die "Nothing for Message to parse!" if (!defined $self->{data});

	my @lines = split(/\n/, $self->{data});
	my $head = 1;
	my $header;
	my @headers;
	my @votes;

	# Grab the From header
	foreach (@lines) {

		if ($head) {
			if ($_ eq '') {
				push(@headers, $header) if ($header ne '');
				$head = 0;
				next;
			}

			if (/^\s+(.+)/) {
				$header .= ' ' . $1;
				next;
			}

			if (/^((\S+):.*)/) {
				push(@headers, $header) if ($header ne '');
				$header = $1;
			}
		} else {
			# Body
			if (/I vote (\S+) on (\S+)/) {
				push(@votes, [$1, $2]);
			}
		}
	}

	$self->{headers} = \@headers;
	$self->{votes} = \@votes;
}

sub print_headers {
	my $self = shift;

	return if (!$self->{headers});

	foreach (@{$self->{headers}}) {
		print "Hdr: $_\n";
	}
}

=pod

	@header_list = $m->headers();

Return a list of all headers appearing in the message, in their order of
appearance. Extension lines beginning with whitespace are concatenated to
the main header with a single space.

=cut

sub headers {
	my $self = shift;

	return @{$self->{headers}};
}

# lowercase names of headers which we will use to extract info ...

my $interesting_headers = {
	'from' => [0, 5, 'name and email of sender'],
	'message-id' => [0, 5, 'message id'],
	'x-fastmail-ip' => [0, 5, 'ip address of sender'],
	'x-freemailid' => [0, 5, 'userid of sender'],
	'x-funmail-uid' => [0, 5, 'userid of sender'],
	'x-mail-from-ip' => [0, 5, 'ip address of sender'],
	'x-mailer' => [0, 5, 'mail program of sender'],
	'x-mdremoteip' => [0, 5, 'inside firewall source ip'],
	'x-originating-ip' => [0, 5, 'ip address of sender'],
	'x-sender-ip' => [0, 5, 'ip address of sender'],
	'x-sender' => [0, 5, 'email address of sender'],
	'x-senders-ip' => [0, 5, 'ip address of sender'],
	'x-sent-from' => [0, 5, 'email address of sender'],
	'x-version' => [0, 5, 'freemail software version'],
	'x-webmail-userid' => [0, 5, 'userid of sender'],
};

# List of IPs which are known to have multiple users (e.g. caches)

my $proxy_ips = [
	['165.228.130.11', 'lon-cache1-1.cache.telstra.net'],
];

my $freemail_regexes = [
	'Get Your Private, Free E-mail from MSN Hotmail',
	'http://www.start.com.au',
	'http://www.hotmail.com',
	'Do You Yahoo!?',
	'Get your free .* address at',
	'Send a cool gift with your E-Card',
	'--== Sent via Deja.com ==--',
	'http://www.eudoramail.com',
	'http://www.netaddress.com/',
	'20 email addresses from',
	'http://www.another.com',
	'Express yourself @ another.com',
	'http://another.com',
	'http://www.MyOwnEmail.com',
	'Free email with personality! Over 200 domains!',
	'http://www.canoe.ca/CanoeMail',
	'This message was sent using OzBytes Webmail',
	'http://www.evilemail.com',
	'http://mbox.com.au',
	'http://webmail.netscape.com/',
	'http://www.zzn.com',
	'Get your free email from',
	'Get free email and a permanent address at',
	'Get Your Private, Free Email at',
	'http://www.burningmail.com',
	'http://www.icq.com/icqmail/signup.html',
	'Get a FREE email address',
	'http://www.WildEmail.com',
	'http://email.tbwt.com',
	'Get Your FREE E-mail Address',
	'http://www.today.com.au',
	'http://www.cubuffs.com',
];

my $received_regex = {
	'\(qmail \d+ invoked from network\);' => [],
	'\(cpmta \d+ invoked from network\);' => [],
	'\(qmail \d+ invoked by uid (\d+)\);' => [],

	'\(from (\S+)\) by (\S+) \([0-9./]+\)' => [],
	'by (\S+) \([0-9./]+\)' => [],
	'by ([a-zA-Z0-9.-]+);' => [],
	'by (\S+) with Internet Mail Service' => [],
	'by (\S+) with Microsoft MAPI' => [],
	'by (\S+) with Microsoft Mail' => [],
	'by (\S+)\(Lotus SMTP MTA' => [],
	'by (\S+) \(Postfix, from userid (\d+)\)' => [],
	'by (\S+) \(Fastmailer' => [],
	'by (\S+) \([0-9.]+.*SMI' => [],

	'from mail pickup service' => [],
	'from ccMail by (\S+) \(IMA' => [],

	'from \[(\S+)\] by (\S+) \(SMTPD32' => [],
	'from \[(\S+)\] by (\S+) \(NTMail' => [],
	'from \[(\S+)\] by (\S+) with ESMTP' => [],
	'from  \[(\S+)\] by (\S+) ' => [],

	'from (\S+)\((\S+) (\S+)\) by ([a-zA-Z0-9.-]+) via smap' => [],
	'from (\S+)\((\S+)\), claiming to be "\S+".* by ([a-zA-Z0-9.-]+),' => [],
	'from (\S+)\((\S+)\) by ([a-zA-Z0-9.-]+) via smap' => [],

	'from (\S+)\(([0-9.]+)\) via SMTP by ([a-zA-Z0-9.-]+),' => [],

	'from (\S+) \(\[(.*)\]\) by ([a-zA-Z0-9.-]+)\(' => [],
	'from (\S+) \[(.*)\] by ([a-zA-Z0-9.-]+) \[(\S+)\] with ' => [],
	'from (\S+) \[(.*)\] by ([a-zA-Z0-9.-]+) with ' => [],
	'from (\S+) \[(.*)\] by ([a-zA-Z0-9.-]+) with ' => [],
	'from (\S+) \[(.*)\] by ([a-zA-Z0-9.-]+) \((.*)\) .*;' => [],

	'from (\S+) by (\S+) for \[(\S+)\]' => [],
	'from (\S+) by (\S+) \(PMDF' => [],
	'from (\S+) by ([a-zA-Z0-9.-]+) with ' => [],
	'from ([a-zA-Z0-9.-]+) \((\S+) \[(\S+)\]\) by ([a-zA-Z0-9.-]+) .*with ' => [],
	'from ([a-zA-Z0-9.-]+) \((.*)\) by ([a-zA-Z0-9.-]+) .*with ' => [],
	'from (\S+) \((.*)\) by ([a-zA-Z0-9.-]+) ' => [],
	'from (.*) by (.*) with ' => [],
	'from (.*) by (.*) ' => [],
};

sub check_received {
	my $self = shift;
	my $header = shift;

	$header =~ s/^Received: //;
	my $match = 0;

	foreach my $regex (keys %$received_regex) {
		if ($header =~ /$regex/) {
			print "Match! $1, $2, $3\n";
			if ($1 eq '') {
				# Unable to parse any actual data from it
				print "Header: $header\n";
			}
			$match = 1;
			last;
		}
	}

	if (!$match) {
		print "No match: $header\n";
	}
}

1;
