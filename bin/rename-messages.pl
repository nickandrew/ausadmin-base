#!/usr/bin/perl
#	@(#) rename-messages.pl - Drop the .pid from message files, safely.

my $last = '';
my $last_path;

foreach my $path (@ARGV) {
	my $file = $path;
	$file =~ s,.*/,,;		# Remove path part, leaving fn
	# expecting yyyymmdd-hhmmss.pid
	$file =~ s/\..*//;
	if ($file eq $last) {
		print "Conflict: $path versus $last_path\n";
	} else {
		my $new_path = $path;
		$new_path =~ s/\..*//;
		rename($path, $new_path);
	}
	$last = $file;
	$last_path = $path;
}
