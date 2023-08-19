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
	# 2023/08/18 03:42:09 [517859] >f+++++++++ var/log/uwsgi/web.ffzg.hr.log-20230818.gz 2451 2410
	my ( $date, $time, $pid, $op, $path, $size, $transfer ) = @v;

	# 2023/08/15 06:30:37 [914596] "*deleting   home/dpavlin/.cache/mozilla/firefox/pf7sl99z.Default User/cache2/entries/B1C52648EB7985A20F46A8BD48539968FC56323E 0 0"
	# 2023/08/18 08:28:12 [1293935] ">f.st...... var/log/libvirt/qemu/homeassistant.log 116371 1989493"
	if ( $#v == 6 ) {
		# nop
	} elsif ( $#v > 6 ) {
		my @v3 = splice(@v, 4);
		$transfer = pop @v3;
		$size     = pop @v3;
		$path     = join(' ', @v3); # re-create path with spaces
		warn "XXX $path | $size" if $debug >= 2;
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

	$stat->{$date}->{$pid}->{$op} += $size if $size;

	my @p = split(/\//, $path);

	#$agg_path =~ s{^(var/log|log|bin|sbin|usr|lib|etc|boot|root|tmp|var/lib/\w+|var/\w+).*}{$1};

	my $to_level = 3; # XXX aggregate 3 levels of dirs
	$to_level = $#p - 1 if ( $#p - 1 < $to_level );

	foreach my $to ( 0 .. $to_level ) {
		my $agg_path = join('/', map { $p[$_] } 0 .. $to );
		$stat->{$date}->{$pid}->{agg}->{ $agg_path }->{$op} += $size;
	}
}

print "# stat = ",dump($stat);
