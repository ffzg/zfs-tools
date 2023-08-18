#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Data::Dump qw(dump);

# this script works with rsync transfer logs if path is host/disk/path or with rrsync
# --log-file-format="%i %n%L %b %l"

my $debug = $ENV{DEBUG} || 0;

my $stat;

while(<>) {
	chomp;
	my @v = split(/\s/,$_);
	my ( $date, $time, $pid, $op, $from_host, $from_ip, $share, undef, $path, $size, $transfer );
	   ( $date, $time, $pid ) = @v;

	# 2023/08/15 06:30:37 [914596] "*deleting   home/dpavlin/.cache/mozilla/firefox/pf7sl99z.Default User/cache2/entries/B1C52648EB7985A20F46A8BD48539968FC56323E 0 0"
	if ( s/"(\S+)\s(.+)\s(\d+)\s(\d+)"// ) {
		( $op, $path, $size, $transfer ) = ( $1,$2,$3,$4 );
	} elsif ( $#v == 9 ) {
		# 2020/04/22 05:44:30 [5950] recv r1u32.gnt.ffzg.hr [10.80.2.51] oscar () ovpn.ffzg.hr/0/var/log/munin/munin-node.log.3.gz 2534
		( $date, $time, $pid, $op, $from_host, $from_ip, $share, undef, $path, $size ) = @v;
	} elsif ( $#v == 6 ) {
		# 2020/04/21 06:25:03 [18843] recv /lib20/rack2/alfa.ffzg.hr etc/.git/logs/refs/heads/master 6239
		( $date, $time, $pid, $op, $from_host, $path, $size ) = @v;
		$from_host =~ s{^.*/}{}; # strip path
		$path = "$from_host/0/$path"; # host/disk/path
	} elsif ( $#v == 7 ) {
		# 2023/08/15 06:25:09 [914596] ">f+++++++++ entries/00037D6A9CD72D90329CEFD53DCC96CDF5A779C3 10680 10640"
		( $date, $time, $pid, $op, $path, $size ) = @v;
warn "XXX ",dump( \@v );
	} else {
		warn "SKIP $#v: [$_]\n" if $debug;
		next;
	}

	if ( $size !~ m/^\d+$/ ) {
		warn "SKIP size=[$size] $_\n";
		next;
	}
	warn "# $date $pid $op $path $size\n" if $debug;

	if ( ++$stat->{$op} % 10000 == 0 ) {
		print STDERR "$op $stat->{$op} ";
	}

	$size = 1 if ( $op eq 'del.' && $size == 0 ); # count deletes

	$stat->{$date}->{$pid}->{$op} += $size;

	my @p = split(/\//, $path);

	#$agg_path =~ s{^(var/log|log|bin|sbin|usr|lib|etc|boot|root|tmp|var/lib/\w+|var/\w+).*}{$1};

	my $to_level = 3; # XXX aggregate 3 levels of dirs
	$to_level = $#p - 1 if ( $#p - 1 < $to_level );

	foreach my $to ( 0 .. $to_level ) {
		my $agg_path = join('/', map { $p[$_] } 0 .. $to );
		warn "XXX $to $agg_path";
		$stat->{$date}->{$pid}->{agg}->{ $agg_path }->{$op} += $size;
	}
}

print "# stat = ",dump($stat);
