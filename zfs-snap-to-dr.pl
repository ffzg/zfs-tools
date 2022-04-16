#!/usr/bin/perl
use warnings;
use strict;
use autodie;

use Data::Dump qw(dump);

my $from_pool = shift @ARGV || 'lib15/oscar';
my $to_host   = shift @ARGV || 'srce01.net.ffzg.hr';	# localhost to skip ssh
my $to_pool   = shift @ARGV || 'srce01';

my $dr_snaps_keep = $ENV{SNAPS_KEEP} || -1; # number of snapshots to keep on dr pool (unlimited)
# use negative number to disable remote snapshots expiration
my $debug = $ENV{DEBUG} || 0;

sub cmd {
	my $cmd = join(' ', @_);
	$cmd =~ s/ssh localhost//g;
	warn "# cmd: $cmd\n" if $debug;
	system($cmd) == 0 or die "system $cmd failed: $?";
}

sub list_snapshots {
	my ($pool, $host) = @_;
	my $ssh = '';
	$ssh = "ssh $host" if $host && $host ne 'localhost';

	warn "# list_snapshots $host $pool\n" if $debug;
	open(my $fh, '-|', "$ssh zfs list -H -r -o name -t snapshot $pool");
	my @s;
	while(<$fh>) {
		chomp;
		push @s, $_;
	}
	close($fh);
	return @s;
}


my @to = list_snapshots( $to_pool, $to_host );
my $to_snap;

sub refresh_to_snap {

$to_snap = {};
@to = list_snapshots( $to_pool, $to_host );
foreach ( @to ) {
	my ($fs,$date) = split(/@/,$_,2);
	$fs =~ s{$to_pool/}{}; # remove dr pool name
	push @{ $to_snap->{$fs} }, $date;
}

warn "# to_snap = ",dump( $to_snap ) if $debug;

} # refresh_to_snap

refresh_to_snap;

my @from = list_snapshots( $from_pool );
my $from_snap;

foreach ( @from ) {
	my ($fs,$date) = split(/@/,$_,2);

	# create fs on remote
	if ( ! exists $to_snap->{$fs} ) {
		cmd "ssh $to_host zfs create -p $to_pool/$fs";
		refresh_to_snap;
	}

	if ( exists $to_snap->{$fs}->[0] ) {
		next if $date lt $to_snap->{$fs}->[0];
	}

	push @{ $from_snap->{$fs} }, $date;
}

foreach my $fs ( sort keys %$from_snap ) {

	# keep last $dr_snaps_keep
	if ( $#{ $from_snap->{$fs} } > $dr_snaps_keep ) {
		$from_snap->{$fs} = [ splice( @{ $from_snap->{$fs} }, -$dr_snaps_keep ) ];
	}

	foreach my $date ( @{ $to_snap->{$fs} } ) {
		if ( $date lt $from_snap->{$fs}->[0]	# older than first snap to keep
			&& $dr_snaps_keep > 0	# disable expiration with negative number
			&& scalar @{ $to_snap->{$fs} } > $dr_snaps_keep # destination has too many snapshots
		) {
			cmd "ssh $to_host zfs destroy $to_pool/$fs\@$date";
			refresh_to_snap;
		}
	}

	my $v = '';
	$v = '-v' if $debug;

	foreach my $i ( 0 .. $#{ $from_snap->{$fs} } ) {
		my $date = $from_snap->{$fs}->[$i];

		if ( ! grep { /^$date$/ } @{ $to_snap->{$fs} } ) {
			if ( $i == 0 ) { # full send if first one
				cmd "zfs send $v $fs\@$date | ssh $to_host zfs receive -F $to_pool/$fs";
				refresh_to_snap;
			} else {
				my $first_date = $to_snap->{$fs}->[-1];
				my $last_date  = $from_snap->{$fs}->[-1];
				cmd "zfs send $v -I $first_date $fs\@$last_date | ssh $to_host zfs receive -F $to_pool/$fs";
				refresh_to_snap;
			}
		}
	}
}

warn "# from_snap = ",dump( $from_snap ) if $debug;


