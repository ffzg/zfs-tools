#!/usr/bin/perl
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

	push @{ $stat->{backups}->{ $tags->{instance} } }, $tags->{date};
}

warn "# stat = ",dump $stat;

my @dates = sort keys %{ $stat->{date} };
my $longest_instance = (sort map { length } keys %{$stat->{instance}})[0];
warn $longest_instance;

foreach my $instance (sort keys %{ $stat->{backups} }) {
	printf "%-20s", $instance;
	my $date;
	foreach my $col ( @dates ) {
		$date ||= shift @{ $stat->{backups}->{$instance} };
		if ( $col lt $date ) {
			print ' ' x length $col;
		} elsif ( $col eq $date ) {
			print $date;
			$date = undef;
		} else {
			print "[$date]";
			$date = undef;
		}
		print " ";
	}
	print "\n";
}
