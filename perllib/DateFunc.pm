#!/usr/bin/perl
#	@(#) DateFunc.pm - Calendar management functions
#
# $Source$
# $Revision$
# $Date$
#
# Methods:
#	dd = lastdayin(mm, yyyy)		Return the highest day No
#	yyyy-mm-dd = addday(yyyy-mm-dd, n_days)	Add n_days to a date
#						n_days < 0 is okay
#	yyyy-mm-dd = nextmonth(yyyy-mm-dd)	Add 1 month to a date
#	yyyy-mm-dd = addmonth(yyyy-mm-dd, n_m)	Add n_m months to a date
#	yyyy-mm-dd = prevday(yyyy-mm-dd)	Return yesterday's date
#	n_days = days_between(start, end)	Return incl. days between

package DateFunc;

# require Exporter;
# use vars qw(@EXPORT);

# Find the last day of a month
# Handle leap years, of course.
sub lastdayin {
	my($im,$iy) = @_;
	my($lastday);

	$lastday = (0,31,28,31,30,31,30,31,31,30,31,30,31)[$im];
	# Check leap year, Feb 29th
	if ($im == 2) {
		if (($iy % 4) == 0 && (($iy % 100) != 0 || ($iy % 400) == 0)) {
			$lastday = 29;
		}
	}

#	print "Last day in m $im y $iy is $lastday\n";
	return $lastday;
}

# Add 1 month to any given date
# E.G. 1997-03-15 => 1997-04-15
# Issues:
# Day of month does not exist in final month
#	=> new day of month becomes last day of previous month
sub nextmonth {
	my($indate) = @_;
	return addmonth($indate, 1);
}

# Subtract 1 day from a date (yyyy-mm-dd)
# No issues here
sub prevday {
	my($indate) = @_;
	my($iy,$im,$id) = split(/-/, $indate);
	$id--;
	if ($id <= 0) {
		$im--;
		if ($im == 0) {
			$im = 12;
			$iy--;
		}
		$id = lastdayin($im, $iy);
	}

	return sprintf("%04d-%02d-%02d", $iy, $im, $id);
}

# Add 'n' months to a date (yyyy-mm-dd)
# E.G. addmonth("1997-03-15", 3) => 1997-06-15
# E.G. addmonth("1997-01-31", 3) => 1997-04-30
# Issues:
# Day of month does not exist in final month
#	=> new day of month becomes last day of previous month
sub addmonth {
	my($indate,$n) = @_;
	my($iy,$im,$id) = split(/-/, $indate);
#	print "addmonth($iy-$im-$id, $n) ...\n";
	$im += $n;
	while ($im > 12) {
		$im -= 12;
		$iy++;
	}
	# Check for day-of-month overflow
	my $lastday = lastdayin($im, $iy);
#	print "Initial result: y $iy m $im lastday $lastday\n";
	if ($id > $lastday) {
		$id = $lastday;
	}

	return sprintf("%04d-%02d-%02d", $iy, $im, $id);
}

# Add 'n' days to a date (yyyy-nn-dd)
# Handles leap years, next year, etc. etc.
# Now also handles n<0 (to subtract days from a date)
sub addday {
	my($indate,$n) = @_;
	my($iy,$im,$id) = split(/-/, $indate);
	$id += $n;
	while ($id > lastdayin($im, $iy)) {
		$id -= lastdayin($im, $iy);
		$im++;
		if ($im > 12) {
			$iy++;
			$im = 1;
		}
	}

	while ($id < 1) {
		$im--;
		if ($im < 1) {
			$iy--;
			$im = 12;
		}
		$id += lastdayin($im, $iy);
	}

	return sprintf "%d-%02d-%02d", $iy, $im, $id;
}

# $days = days_between($start_date, $end_date)
# Returns a value of 0 if the days are the same!

sub days_between {
	my($start_date, $end_date) = @_;
	my $days = 0;
	my $sign = 1;

	if ($start_date gt $end_date) {
		my $temp_date = $start_date;
		$start_date = $end_date;
		$end_date = $temp_date;
		$sign = -1;
	}

	while ($start_date lt $end_date) {
		$start_date = DateFunc::addday($start_date, 1);
		$days++;
	}

	return $days * $sign;
}

sub find_fy {
	my $date = shift;

	my($yyyy,$mm,$dd) = split(/-/, $date);

	if ($mm < 7) {
		# 1998-01 => 1998
		return $yyyy;
	}

	# 1998-07 => 1999
	return $yyyy + 1;
}

1;

# end of DateFunc.pm
