#!/usr/bin/perl -w

# Generate headers so that it looks like that it has been posted via 
# a system.

@read=<>;


($sec,$min,$hour,$mday,$mon,$year) = localtime(time);

$monthname=("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")[$mon];

$year += 1900; $mon++;

print "Path: aus.news-admin.org!not-for-mail\n";
print "Message-id: <$^T|$$|ausadmin\@aus.news-admin.org>\n" if not grep /^Message-ID/,@read;
print "Date: $mday $monthname $year $hour:$min:$sec\n" if not grep /^Date/,@read;

print @read;
