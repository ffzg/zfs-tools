#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use Data::Dump qw(dump);

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

	push @{ $stat->{backups}->{ $tags->{instance} } }, $tags->{date};
}

warn "# stat = ",dump $stat;

my @dates = sort keys %{ $stat->{date} };
my $longest_instance = (sort map { length } keys %{$stat->{instance}})[0] + 1;

sub h_size {
	my $s = shift;
	my @unit = ( ' ', 'K', 'M', 'G', 'T' );
	my $i = 0;
	while ( $s > 1024 ) {
		$s = $s / 1024;
		$i++;
		last if $i == $#unit;
	}
	#warn "# h_size $s $i $unit[$i]";
	return sprintf " %5.1f%s", $s, $unit[$i];
}

my $show_size = $ENV{SIZE} || $ARGV[0];

foreach my $instance (sort keys %{ $stat->{backups} }) {
	printf "%-20s", $instance;
	my $date;
	foreach my $col ( @dates ) {
		$date ||= shift @{ $stat->{backups}->{$instance} };
		if ( $col lt $date ) {
			print ' ' x length $col;
			print '       ' if $show_size;
		} elsif ( $col eq $date ) {
			print $date;
			print h_size($stat->{size}->{$instance}->{$date}) if $show_size;
			$date = undef;
		} else {
			print "[$date]";
			print h_size($stat->{size}->{$instance}->{$date}) if $show_size;
			$date = undef;
		}
		print " ";
	}
	print "\n";
}
