#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Getopt::Long;
use English; # $UID
use Data::Dump qw(dump);

# this scripts lists all backups in following naming format:
# pool/..ignored../instance/disk_nr@yyyy-mm-dd
# pool/..ignored../instance@yyyy-mm-dd

my $show_date;
my $show_size;
my $show_last;
my $show_used;

GetOptions (
	"date"	=> \$show_date,
	"size"	=> \$show_size,
	"last=i" => \$show_last,
	"used"	=> \$show_used,
) or die("Error in command line arguments", dump @ARGV);

my $debug = $ENV{DEBUG} || 0;

( $show_date, $show_size ) = ( 1,1 ) if ! defined $show_date && ! defined $show_size;

my $pool = $ENV{ZFS_POOL} || `zpool list -H -o name`;
chomp($pool);

my @props = qw(
name
creation
used
referenced
compressratio
refcompressratio
written
logicalused
logicalreferenced
);

my $stat;

open(my $s_fh, '>', '/dev/shm/zfs.snapshots');

open(my $list, '-|', 'sudo zfs list -H -p -o '.join(',',@props)." -t snapshot -r $pool");
while(<$list>) {
	print $s_fh $_;
	chomp;
	my @v = split(/\t/,$_);
	my %h;
	@h{@props} = @v;
	warn "# h = ",dump(\%h) if $debug;

	my @t = split(/[\/@]/,$h{name});
	warn "# t = ", dump @t if $debug;

	my $tags;
	( $tags->{node}, $tags->{instance}, $tags->{disk}, $tags->{date} ) = @t[-5, -3, -2, -1 ];
	if ( $tags->{disk} !~ m{^\d$} ) {
		( $tags->{node}, $tags->{instance}, $tags->{disk}, $tags->{date} ) = ( @t[-3, -2], 0, $t[ -1 ] );
	}
	if ( $#t == 3 ) {
		$tags->{date} = $t[-1];
		$tags->{disk} = 0;
	}

	# XXX special case - accumulate all snapshots below
	if ( $h{name} =~ m{zamd/mglavica/mlinz} ) {
		( $tags->{instance}, $tags->{disk}, $tags->{date} ) = ( 'mlin', 0, $t[-1] );
	}

	# support sanoid snapshots
	$tags->{date} =~ s/autosnap_(\d\d\d\d-\d\d-\d\d)_\d\d:\d\d:\d\d_daily/$1/;

	warn "# tags = ",dump($tags) if $debug;

	if ( $tags->{date} !~ m/^\d\d\d\d-\d\d-\d\d$/ ) {
		warn "SKIPPED, invalid date $tags->{date}";
		next;
	}

	$stat->{$_}->{ $tags->{$_} }++ foreach (qw( instance date ));

	if ( $show_used ) {
		$stat->{size}->{ $tags->{instance} }->{ $tags->{date} } += $h{used};
		$stat->{date_size}->{ $tags->{date} } += $h{used};
	} else {
		$stat->{size}->{ $tags->{instance} }->{ $tags->{date} } += $h{written};
		$stat->{date_size}->{ $tags->{date} } += $h{written};
	}
	push @{ $stat->{date_disks}->{ $tags->{date} } }, $tags->{disk};

	push @{ $stat->{backups}->{ $tags->{instance} } }, $tags->{date};
}

warn "# stat = ",dump $stat if $debug;

my @dates = sort keys %{ $stat->{date} };
my $longest_instance = (sort { $b <=> $a } map { length } keys %{$stat->{instance}})[0] + 1;

sub h_size {
	my $s = shift;
	my @unit = ( ' ', 'K', 'M', 'G', 'T' );
	my $i = 0;
	while ( $s > 1024 ) {
		$s = $s / 1024;
		$i++;
		last if $i == $#unit;
	}
	my $ff =
		$s <   9.995 ? 2 : # < 10 is not good, because 9.996 will become 10.00 in sprintf rounding
		$s <  99.95  ? 1 :
		0;
	my $fi = 4 - $ff;
	#warn "# h_size $s $i $fi $ff $unit[$i]";
	return sprintf "%${fi}.${ff}f%s", $s, $unit[$i];
}

my $last = $#dates;
$last = $show_last - 1 if defined $show_last;
$last = $#dates if $last > $#dates; # limit just to existing backups

sub unique_splice {
	my ( $array, $from ) = @_;
	my %u;
	return grep { defined && $_ ge $from } map { ++$u{$_} == 1 ? $_ : undef } sort @$array;
}

my $proxmox;

open(my $proxmox_fh, '<', '/zamd/proxmox/qm.list');
my $h = <$proxmox_fh>;
while(<$proxmox_fh>) {
	chomp;
	s/^\s+//;
	my ( $id, $name, undef ) = split(/\s+/, $_, 3 );

	$proxmox->{$id} = $name;
}
close($proxmox_fh);


$pool =~ s{/}{_}g if $pool =~ m{/};

open(my $out, '>', "/dev/shm/$pool-list.txt");
open(my $csv, '>', "/dev/shm/$pool.backups.csv");

my $dates;

foreach my $instance (sort keys %{ $stat->{backups} }) {
	my $date;
	my @backup_dates = unique_splice( $stat->{backups}->{$instance}, $dates[$#dates - $last]);
	#warn "# instance $instance ",dump(@backup_dates);
	my $instance_name = $instance;
	if ( $instance_name =~ /vm-(\d+)-disk-\d+/ ) {
		$instance_name = $1 . ' ' . $proxmox->{$1};
	}
	my @line = ( sprintf("%-${longest_instance}s", $instance_name) );
	foreach my $i ( $#dates - $last .. $#dates ) {
		my $col = $dates[$i];
		$date ||= shift @backup_dates;
		$dates->{$date}++;
		#warn "# $instance $col ? $date\n";
		if ( ! $date || $col lt $date ) {
			push @line, ' ' x length($col) if $show_date;
			push @line, '     ' if $show_size;
		} else { # $col eq $date
			push @line, $date if $show_date;
			push @line, h_size($stat->{size}->{$instance}->{$date}) if $show_size;
			$stat->{backup_count}->{$date}++;
			print $csv "$date,$instance_name,$stat->{size}->{$instance}->{$date}\n";
			$date = undef;
		}
	}
	push @line, sprintf("%-${longest_instance}s", $instance_name);
	print $out join(' ',@line), "\n";
	print join(' ',@line), "\n";

}

close($csv);

open(my $csv, '>', "/dev/shm/$pool-instances.csv");

my @instances = sort keys %{ $stat->{backups} };
my @dates     = sort keys %$dates;

print $csv join(',', 'date', @instances ), "\n";
foreach my $date ( @dates ) {

	my @v = ( $date );

	foreach my $instance ( @instances ) {
		push @v, $stat->{size}->{$instance}->{$date};
	}

	print $csv join(',', @v), "\n";
}

close($csv);

if ( $show_size ) {

	my @backup_dates = splice( @dates, $#dates - $last);
	my @line = ( ' ' x $longest_instance );
	foreach my $col ( @backup_dates ) {
		push @line, sprintf("%8s =",join('/', $stat->{backup_count}->{$col}, $#{$stat->{date_disks}->{$col}}+1)) if $show_date;
		push @line, h_size($stat->{date_size}->{$col}) if $show_size;
	}
	print $out join(' ',@line),"\n";
	print join(' ',@line),"\n";

}
