#!/usr/bin/perl
#	Emit a series of links to newsgroups work in progress

chdir "../Wip";
$count = 0;
for $fn (<*>) {
	open(F, "<$fn") || next;
	undef %data;

	while (<F>) {
		chop;
		last if (/^$/);
		($key, $value) = ($_ =~ /([^:]*):\s+(.*)/);
#		print "key: $key, value: /$value/\n";
		$data{$key} = $value;
	}

	close(F);
	$key = $fn;
	if ($data{Updated} ne "") {
		$key = "$data{Updated} $fn";
	}
	print "Key is $key\n";

	$keys{$key} = 1;
	if ($data{Name} ne "") {
		$text{$key} = $data{Name};
	} else {
		$text{$key} = $fn;
	}

	$fn{$key} = $fn;
	$updated{$key} = $data{Updated};
	$link{$key} = $data{Link};
	$status{$key} = $data{Status};
}

# Emit gathered info
for $key (sort (keys %keys)) {
	print "<li>";
	if ($link{$key} ne "n") {
		printf "<a href=\"%s\">", ($link{$key} eq "" ? "/Wip/$fn{$key}" : $link{$key});
	}
	print $text{$key};
	if ($link{$key} ne "n") {
		printf "</a>";
	}
	if ($updated{$key} ne "") {
		print " Updated: $updated{$key}";
	}
	print "\n";
	$count++;
}

if ($count == 0) {
	print "<li>None at present\n";
}
