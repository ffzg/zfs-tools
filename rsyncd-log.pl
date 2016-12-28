#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Data::Dump qw(dump);

my $stat;

while(<>) {
	chomp;
	my @v = split(/\s/,$_);
	if ( $#v != 9 ) {
		#warn "SKIP: [$_]\n";
		next;
	}
	my ( $date, $time, $pid, $op, $from_host, $from_ip, $share, undef, $path, $size ) = @v;
	#warn "# $date $pid $op $path $size\n";
	if ( ++$stat->{$op} % 10000 == 0 ) {
		print STDERR "$op $stat->{$op} ";
	}

	$size = 1 if ( $op eq 'del.' && $size == 0 ); # count deletes

	$stat->{$date}->{$pid}->{$op} += $size;
	my @p = split(/\//, $path);

	$stat->{$date}->{$pid}->{host} ||= $p[0];
	$stat->{$date}->{$pid}->{disk} ||= $p[1];


	my $e = 2;
	@p = splice(@p, 2, $e);

	my $agg_path = join('/',@p);
	$agg_path =~ s{^(var/log|tmp|log).*}{$1};
	$stat->{$date}->{$pid}->{agg}->{ $agg_path }->{$op} += $size;
}

print "# stat = ",dump($stat);
