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

	$self->{path} = 'string';

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

	$self->{path} = $path;

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

$Message::interesting_headers = {
	'from' => [0, 5, 'name and email of sender', '(.*)', ['junk']],
	'message-id' => [0, 5, 'message id', '(.*)', ['junk']],
	'x-fastmail-ip' => [0, 5, 'ip address of sender', '(.*)', ['ip']],
	'x-freemailid' => [0, 5, 'userid of sender', '(.*)', ['uid']],
	'x-funmail-uid' => [0, 5, 'userid of sender', '(.*)', ['uid']],
	'x-mail-from-ip' => [0, 5, 'ip address of sender', '\[(.*)\]', ['ip']],
	'x-mailer' => [0, 5, 'mail program of sender', '(.*)', ['mailer']],
	'x-mdremoteip' => [0, 5, 'inside firewall source ip', '(.*)', ['ip']],
	'x-originating-ip' => [0, 5, 'ip address of sender', '\[(.*)\]', ['ip']],
	'x-sender-ip' => [0, 5, 'ip address of sender', '(.*)', ['ip']],
	'x-sender' => [0, 5, 'email address of sender'],
	'x-senders-ip' => [0, 5, 'ip address of sender', '(.*)', ['ip']],
	'x-sent-from' => [0, 5, 'email address of sender'],
	'x-version' => [0, 5, 'freemail software version', '(.*)', ['fm_vers']],
	'x-webmail-userid' => [0, 5, 'userid of sender', '(.*)', ['uid']],
};

# List of IPs which are known to have multiple users (e.g. caches)

my $proxy_ips = [
	['165.228.130.11', 'lon-cache1-1.cache.telstra.net'],
	['203.108.0.57', 'netcachesyd1.ozemail.com.au'],
	['203.164.3.179', 'cfw4-2.rdc1.nsw.excitehome.net.au'],
	['198.142.200.243', 'cache06.syd.optusnet.com.au'],
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

my $received_regex = [
	['\(qmail \d+ invoked from network\);', []],
	['\(cpmta \d+ invoked from network\);', []],
	['\(qmail \d+ invoked by uid (\d+)\);', []],

	['\(from (\S+)\) by (\S+) \([0-9./]+\)', []],
	['by (\S+) \([0-9./]+\)', []],
	['by ([a-zA-Z0-9.-]+);', []],
	['by (\S+) with Internet Mail Service', []],
	['by (\S+) with Microsoft MAPI', []],
	['by (\S+) with Microsoft Mail', []],
	['by (\S+)\(Lotus SMTP MTA', []],
	['by (\S+) \(Postfix, from userid (\d+)\)', []],
	['by (\S+) \(Fastmailer', []],
	['by (\S+) \([0-9.]+.*SMI', []],

	['from mail pickup service', []],
	['from ccMail by (\S+) \(IMA', []],

	['from \[(\S+)\] by (\S+) \(SMTPD32', []],
	['from \[(\S+)\] by (\S+) \(NTMail', []],
	['from \[(\S+)\] by (\S+) with ESMTP', []],
	['from  \[(\S+)\] by (\S+);', ['src-ip', 'dst-hostname']],
	['from  \[(\S+)\] by (\S+) ', ['src-ip', 'dst-hostname']],

	['from (\S+)\((\S+) (\S+)\) by ([a-zA-Z0-9.-]+) via smap', []],
	['from (\S+)\((\S+)\), claiming to be "\S+".* by ([a-zA-Z0-9.-]+),', []],
	['from (\S+)\((\S+)\) by ([a-zA-Z0-9.-]+) via smap', []],

	['from (\S+)\(([0-9.]+)\) via SMTP by ([a-zA-Z0-9.-]+),', []],

	['from (\S+) \(\[(.*)\]\) by ([a-zA-Z0-9.-]+)\(', ['src-hostname', 'src-ip', 'dst-hostname']],
	['from (\S+) \[(.*)\] by ([a-zA-Z0-9.-]+) \[(\S+)\] with ', []],
	['from (\S+) \[(.*)\] by ([a-zA-Z0-9.-]+) with ', []],
	['from (\S+) \[(.*)\] by ([a-zA-Z0-9.-]+) with ', []],
	['from (\S+) \[(.*)\] by ([a-zA-Z0-9.-]+) \((.*)\) .*;', []],

	['from (\S+) by (\S+) for \[(\S+)\]', []],
	['from (\S+) by (\S+) \(PMDF', []],
	['from (\S+) by ([a-zA-Z0-9.-]+) with ', []],
	['from ([a-zA-Z0-9.-]+) \((\S+) \[(\S+)\]\) by ([a-zA-Z0-9.-]+) .*with ', ['src-hostname', 'src-ip', 'dst-hostname']],
	['from ([a-zA-Z0-9.-]+) \((.*)\) by ([a-zA-Z0-9.-]+) .*with ', ['src-hostname', 'src-ip', 'dst-hostname']],
	['from (\S+) \((.*)\) by ([a-zA-Z0-9.-]+) ', []],
	['from (.*) by (.*) with ', []],
	['from (.*) by (.*) ', []],
];

sub check_received {
	my $self = shift;
	my $header = shift;

	$header =~ s/^Received: //;
	my $match = 0;

	foreach my $r (@$received_regex) {
		my $regex = $r->[0];
		my $hash_map = $r->[1];

		if ($header =~ /$regex/) {
			print "Header: $header\n";
			print "Matched this regex: $regex\n";
			print "References: $1, $2, $3\n";

			my $data_hr = { };

			# Ok, we got something. Now grab the contents and stick in hashref
			my @refs = ($1,$2,$3,$4,$5,$6,$7,$8,$9);

			foreach (@$hash_map) {
				if ($_) {
					push(@{$data_hr->{$_}}, shift @refs);
				} else {
					# This substring match was not required
					shift @refs;
				}
			}

			# Print out the useful data
			print "The data we got was:\n";
			foreach my $v (sort (keys %$data_hr)) {
				printf "\t%-20s :", $v;
				foreach my $l (@{$data_hr->{$v}}) {
					print ' ', $l;
				}
				print "\n";
			}

			print "\n";

			# Grab the useful data
			$match = 1;
			last;
		}
	}

	if (!$match) {
		print "No match: $header\n";
	}
}

=pod

$info_hr = Message::parse_header($string, $how_lr, $data_hr) ...

Extract useful information from this string, using $how_lr (it's a
reference to a list, which is defined in $Message::interesting_headers).

The $string is the value of the header, sans its name.

Update the supplied hashref argument, and return 1 if all this worked,
or 0 if the value didn't match the regex.

=cut

sub parse_header {
	my $string = shift;
	my $how_lr = shift;
	my $data_hr = shift;

	my $regex = $how_lr->[3];
	my $hash_map = $how_lr->[4];

	return undef if (!defined $regex);
	return undef if (!defined $hash_map);

	if ($string =~ /$regex/) {
		# Ok, we got something. Now grab the contents and stick in hashref
		my @refs = ($1,$2,$3,$4,$5,$6,$7,$8,$9);
		foreach (@$hash_map) {
			if ($_) {
				push(@{$data_hr->{$_}}, shift @refs);
			} else {
				# This substring match was not required
				shift @refs;
			}
		}

		return 1;
	}

	# Oops, nothing matched
	return 0;
}


=pod

header_info() ...

Check every interesting header and extract the data contained in it.
Organise all data by name and return a reference to a hash: the key
is the identifier for the data's meaning, and the value is a reference
to a list of extracted strings for that identifier.

=cut

sub header_info {
	my $self = shift;

	my @header_l = $self->headers();
	my $int_hr = $Message::interesting_headers;
	my $data_hr = { };

	foreach (@header_l) {
		if (/^([^:]+): (.*)/) {
			my $hdr_name = lc($1);
#			print "Checking: $hdr_name\n";
			if (!exists $int_hr->{$hdr_name}) {
				# Not interesting
				next;
			}

			# Hmm. How do we get the data out? A regex!
			Message::parse_header($2, $int_hr->{$hdr_name}, $data_hr);
		} else {
			print "Invalid header: $_\n";
		}
	}

	return $data_hr;
}

=pod

 $data_hr->{'interesting-datatype'} = [ 'value', 'value', ... ]
 print_interesting($data_hr) ...

Output the contents of this interesting data to STDOUT.

=cut

sub print_interesting {
	my $data_hr = shift;

	if (ref $data_hr) {
		print " WOW ...\n";
		foreach my $r (sort (keys %$data_hr)) {
			printf "  %s: ", $r;
			if (ref $data_hr->{$r}) {
				# Value is a list
				foreach (@{$data_hr->{$r}}) {
					printf "%s | ", $_;
				}
				print "\n";
			} elsif (!defined $data_hr->{$r}) {
				print "?\n";
			} else {
				print $data_hr->{$r}, "\n";
			}
		}
		print "\n";
	}
}

1;
