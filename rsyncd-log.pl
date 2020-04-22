#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Data::Dump qw(dump);

# this script works with rsync transfer logs if path is host/disk/path or with rrsync

my $debug = $ENV{DEBUG} || 0;

my $stat;

while(<>) {
	chomp;
	my @v = split(/\s/,$_);
	my ( $date, $time, $pid, $op, $from_host, $from_ip, $share, undef, $path, $size );
	if ( $#v == 9 ) {
		# 2020/04/22 05:44:30 [5950] recv r1u32.gnt.ffzg.hr [10.80.2.51] oscar () ovpn.ffzg.hr/0/var/log/munin/munin-node.log.3.gz 2534
		( $date, $time, $pid, $op, $from_host, $from_ip, $share, undef, $path, $size ) = @v;
	} elsif ( $#v == 6 ) {
		# 2020/04/21 06:25:03 [18843] recv /lib20/rack2/alfa.ffzg.hr etc/.git/logs/refs/heads/master 6239
		( $date, $time, $pid, $op, $from_host, $path, $size ) = @v;
		$from_host =~ s{^.*/}{}; # strip path
		$path = "$from_host/0/$path"; # host/disk/path
	} else {
		warn "SKIP $#v: [$_]\n" if $debug;
		next;
	}

	if ( $size !~ m/^\d+$/ ) {
		warn "SKIP $_\n";
		next;
	}
	warn "# $date $pid $op $path $size\n" if $debug;

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
	$agg_path =~ s{^(var/log|log|bin|sbin|usr|lib|etc|boot|root|tmp|var/lib/\w+|var/\w+).*}{$1};
	$stat->{$date}->{$pid}->{agg}->{ $agg_path }->{$op} += $size;
}

print "# stat = ",dump($stat);
