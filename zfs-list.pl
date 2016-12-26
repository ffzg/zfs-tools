#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Getopt::Long;
use Data::Dump qw(dump);

my $show_date;
my $show_size;
my $show_last;

GetOptions (
	"date"	=> \$show_date,
	"size"	=> \$show_size,
	"last=i" => \$show_last,
) or die("Error in command line arguments", dump @ARGV);

( $show_date, $show_size ) = ( 1,1 ) if ! defined $show_date && ! defined $show_size;

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

open(my $list, '-|', 'sudo zfs list -H -p -o '.join(',',@props).' -t snapshot -r lib15/backup');
while(<$list>) {
	chomp;
	my @v = split(/\t/,$_);
	my %h;
	@h{@props} = @v;
	warn "# h = ",dump(\%h);

	my @t = split(/[\/@]/,$h{name});
	warn "# t = ", dump @t;

	my $tags;
	( $tags->{node}, undef, $tags->{instance}, $tags->{disk}, $tags->{date} ) = @t;
	warn "# tags = ",dump($tags);

	$stat->{$_}->{ $tags->{$_} }++ foreach (qw( instance date ));

	$stat->{size}->{ $tags->{instance} }->{ $tags->{date} } += $h{written};
	$stat->{date_size}->{ $tags->{date} } += $h{written};

	push @{ $stat->{backups}->{ $tags->{instance} } }, $tags->{date};
}

warn "# stat = ",dump $stat;

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
		$s <   10 ? 2 :
		$s <  100 ? 1 :
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
	return grep { defined && $_ ge $from } map { ++$u{$_} == 1 ? $_ : undef } @$array;
}


foreach my $instance (sort keys %{ $stat->{backups} }) {
	my $date;
	my @backup_dates = unique_splice( $stat->{backups}->{$instance}, $dates[$#dates - $last]);
	#warn "# instance $instance ",dump(@backup_dates);
	my @line = ( sprintf("%-${longest_instance}s", $instance) );
	foreach my $i ( $#dates - $last .. $#dates ) {
		my $col = $dates[$i];
		$date ||= shift @backup_dates;
		#warn "# $instance $col ? $date\n";
		if ( $col lt $date ) {
			push @line, ' ' x length($col) if $show_date;
			push @line, '     ' if $show_size;
		} else { # $col eq $date
			push @line, $date if $show_date;
			push @line, h_size($stat->{size}->{$instance}->{$date}) if $show_size;
			$stat->{backup_count}->{$date}++;
			$date = undef;
		}
	}
	print join(' ',@line), "\n";
}

if ( $show_size ) {

	my @backup_dates = splice( @dates, $#dates - $last);
	my @line = ( ' ' x $longest_instance );
	foreach my $col ( @backup_dates ) {
		push @line, sprintf("%8d =",$stat->{backup_count}->{$col}) if $show_date;
		push @line, h_size($stat->{date_size}->{$col}) if $show_size;
	}
	print join(' ',@line),"\n";

}
