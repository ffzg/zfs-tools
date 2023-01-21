#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

my ( $from, $to ) = @ARGV;

die "Usage: $0 host1:pool1/fs1 host2:pool2/fs2\n" unless $from && $to;

my ( $from_host, $from_pool ) = $from =~ m/:/ ? split(/:/, $from) : ( '', $from );
my ( $to_host,   $to_pool   ) = $to   =~ m/:/ ? split(/:/, $to)   : ( '', $to );

my $debug = $ENV{DEBUG} || 0;
my $v = '';
$v = '-v' if $ENV{VERBOSE} || $debug;

my $rate = $ENV{RATE} || '100M'; # XXX
my $exclude = $ENV{EXCLUDE} || '/clone/'; # FIXME

my $from_ssh = "ssh $from_host" if $from_host;
my $to_ssh   = "ssh $to_host"   if $to_host;
$from_ssh //= '';
$to_ssh //= '';

warn "# from $from_host : $from_pool [$from_ssh]";
warn "# to $to_host : $to_pool [$to_ssh]";

sub cmd {
	my $cmd = join(' ', @_);
	$cmd =~ s/ssh localhost//g;
	warn "# cmd: $cmd\n" if $debug;
	system($cmd) == 0 or die "system $cmd failed: $?";
}

sub cmd_pipe {
	my ( $from_ssh, $from_cmd, $to_ssh, $to_cmd ) = @_;
	my $cmd = '';
	# use compression and mbuffer only if over network
	if ( $from_ssh || $to_ssh ) {
		$from_cmd = "$from_cmd | zstd";
		#$from_cmd .= " | mbuffer -s 128k -R $rate"; ## XXX remove mbuffer
		$to_cmd =   "zstd -d | $to_cmd";
	}
	if ( $from_ssh ) {
		$cmd = "$from_ssh '$from_cmd'";
	} else {
		$cmd = $from_cmd;
	}
	if ( $to_ssh ) {
		$cmd .= " | $to_ssh '$to_cmd'";
	} else {
		$cmd .= " | $to_cmd";
	}
	warn "# cmd_pipe: $cmd\n" if $debug;
	system($cmd) == 0 or die "system $cmd failed: $?";

}

sub list {
	my ($host, $pool, $type) = @_;
	my $ssh = '';
	$ssh = "ssh $host" if $host && $host ne 'localhost';
	$type //= '';

	warn "# list [$ssh] $host : $pool [ $type ]\n" if $debug;
	open(my $fh, '-|', "$ssh zfs list -r -H -o name $type $pool");
	my @s;
	my $s;

	while(<$fh>) {
		chomp;
		next if m{$exclude};
		s/^$pool//;
		push @s, $_;
		$s->{ $_ } = $#s;
	}
	#close($fh); # FIXME it target doesn't exists, don't die
	return ( [ @s ], $s );
}

sub sync_snapshot {
	my ( $from_host, $from_pool, $to_host, $to_pool ) = @_;
	warn "# sync_snapshots $from_pool $to_host $to_pool\n";

	my ( $from, $from_h ) = list( $from_host, $from_pool, '-t snapshot' );
	warn "# from = ",dump( $from ) if $debug;
	my ( $to,   $to_h   ) = list( $to_host,   $to_pool,   '-t snapshot' );
	warn "# to = ",dump( $to ) if $debug;

	if ( $#{$from} == -1 ) {
		warn "SKIPPED $from_pool, no snapshots";
		return;
	}

	my $start;
	my $end;

	foreach ( 0 .. $#{$to} ) {
		my $i = $#{$to} - $_;
		my $s = $to->[$i];
		if ( exists $from_h->{$s} ) {
			my $e      = $from->[-1];
			my $s_path = $s; $s_path =~ s{\@.+}{};
			my $e_path = $e; $e_path =~ s{\@.+}{};
			if ( $s_path eq $e_path ) {
				$start = $s;
				$end   = $e;
				warn "# got $start -- $end\n";
				last;
			}
		} else {
			warn "SKIP $i $to_pool/$s missing\n";
		}
	}

	if ( $#{$to} == -1 ) { # no desination snapshots, transfer everything
		my $last = $from->[0];
		my $path = $last;
		$path =~ s/\@.+$//;

		if ( ! exists( $to_h->{ $last } ) ) {
			cmd "$to_ssh zfs create -p $to_pool" . $path;
		}

		cmd_pipe $from_ssh, "zfs send $v -R $from_pool$last", $to_ssh, "zfs receive -F -x mountpoint $to_pool$path";
		return;
	}

	die "can't find common snapshot beween $from_pool and $to_pool in ",dump( [ $from ], [ $to ] ) unless $start;

	my $start_snap = $start;
	$start_snap =~ s{^.+\@}{};
	my $end_path   = $end;
	$end_path   =~ s/\@.+$//;

	return if $start eq $end;

	# FIXME -F shouldn't really be needed, but it is
	cmd_pipe $from_ssh, "zfs send $v -I $start_snap $from_pool$end", $to_ssh, "zfs receive -F -x mountpoint $to_pool$end_path";

}


my ( $from, $from_h ) = list( $from_host, $from_pool, '-r' );
warn "# from = ",dump( $from ) if $debug;
my ( $to,   $to_h   ) = list( $to_host,   $to_pool,   '-r' );
warn "# to = ",dump( $to ) if $debug;

foreach my $i ( 0 .. $#{$from} ) {
	next if $from->[$i] eq ''; # FIXME don't try to sync whole pool
	warn "XX $from->[$i]\n";

	sync_snapshot( $from_host, $from_pool . $from->[$i], $to_host, $to_pool . $from->[$i] );
}
