#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

my $from_pool = shift @ARGV || 'zamd';
my $to_host   = shift @ARGV || 'localhost';	# localhost to skip ssh
my $to_pool   = shift @ARGV || 't3/zamd';

my $debug = $ENV{DEBUG} || 1;
my $v = '';
$v = '-v' if $debug;

sub cmd {
	my $cmd = join(' ', @_);
	$cmd =~ s/ssh localhost//g;
	warn "# cmd: $cmd\n" if $debug;
	system($cmd) == 0 or die "system $cmd failed: $?";
}

sub list {
	my ($pool, $host, $type) = @_;
	my $ssh = '';
	$ssh = "ssh $host" if $host && $host ne 'localhost';
	$type //= '';

	warn "# list_snapshots $type $host $pool\n" if $debug;
	open(my $fh, '-|', "$ssh zfs list -H -o name $type $pool");
	my @s;
	my $s;

	while(<$fh>) {
		chomp;
		s/^$pool//;
		push @s, $_;
		$s->{ $_ } = $#s;
	}
	close($fh);
	return ( [ @s ], $s );
}

sub list_snapshots {
	my ($pool, $host) = @_;
	return list( $pool, $host, '-t snapshot');
}

sub sync_snapshot {
	my ( $from_pool, $to_host, $to_pool ) = @_;
	warn "# sync_snapshots $from_pool $to_host $to_pool\n";

	my ( $from, $from_h ) = list_snapshots( $from_pool );
	my ( $to,   $to_h   ) = list_snapshots( $to_pool, $to_host );

	#warn "# from = ",dump( $from );
	#warn "# to = ",dump( $to );

	if ( $#{$from} == -1 ) {
		warn "SKIPPED $from_pool, no snapshots";
		return;
	}

	if ( $#{$to} == -1 ) { # no desination snapshots, transfer everything
		my $last = $from->[-1];
		my $path = $last;
		$path =~ s/\@.+$//;
		cmd "zfs send $v -R $from_pool$last | ssh $to_host zfs receive -F -x mountpoint $to_pool$path";
		return;
	}

	my $start;
	my $end;

	foreach ( 0 .. $#{$to} ) {
		my $i = $#{$to} - $_;
		my $s = $to->[$i];
		if ( exists $from_h->{$s} ) {
			$start = $s;
			$end   = $from->[-1];
			warn "# got $start -- $end\n";
			last;
		} else {
			warn "SKIP $i $to_pool/$s missing\n";
		}
	}

	die "can't find common snapshot beween $from_pool and $to_pool in ",dump( [ $from ], [ $to ] ) unless $start;

	my $start_snap = $start;
	$start_snap =~ s{^.+\@}{};
	my $end_path   = $end;
	$end_path   =~ s/\@.+$//;

	return if $start eq $end;

	# FIXME -F shouldn't really be needed, but it is
	cmd "zfs send $v -I $start_snap $from_pool$end | ssh $to_host zfs receive -F -x mountpoint $to_pool$end_path";

}


my ( $from, $from_h ) = list( $from_pool, '',       '-r' );
my ( $to,   $to_h   ) = list( $to_pool,   $to_host, '-r' );

warn "# from = ",dump( $from );
warn "# to = ",dump( $to );

foreach my $i ( 0 .. $#{$from} ) {
	warn "XX $from->[$i]\n";

	if ( ! exists( $to_h->{ $from->[$i] } ) ) {
		cmd "zfs create $to_pool" . $from->[$i];
	}

	sync_snapshot( $from_pool . $from->[$i], $to_host, $to_pool . $from->[$i] );
}
