#!/usr/bin/perl
#	@(#) find-message-dupes.pl - Find any files which would have a
#	name conflict if the pid were removed (i.e. 2 messages received
#	within one second)

my $last = '';
my $last_path;

foreach my $path (@ARGV) {
	my $file = $path;
	$file =~ s,.*/,,;		# Remove path part, leaving fn
	# expecting yyyymmdd-hhmmss.pid
	$file =~ s/\..*//;
	if ($file eq $last) {
		print "Conflict: $path versus $last_path\n";
	}
	$last = $file;
	$last_path = $path;
}
