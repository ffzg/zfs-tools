#!/usr/bin/perl
use warnings;
use strict;
use autodie;
use YAML;
use Data::Dump qw(dump);

my $instance = $ARGV[0];
my $restore_date = $ARGV[1];

my @i = glob "/zamd/ganeti/*-instances/$instance*";

my $instance_file = $i[0];

die "ERROR: more than one instance for [$instance] ",dump(@i) if $#i > 0;

my $y = YAML::LoadFile( $instance_file );

$instance =~ s/\.$// && warn "removed trailing dot from $instance";
print "$instance from $instance_file\n";

my $disks = $y->[0]->{Disks};
#warn "# disks=",dump($disks);

print "disks: $#$disks\n";

my @disks_glob = grep { ! m{/clone/} } glob "/zamd/*/$instance*/[0-9]";

if ( $#disks_glob != $#$disks ) {
	warn "ERROR: not all disks found in backup ",dump( \@disks_glob, $disks );
}

print "disks_glob: @disks_glob\n";

my $path = $disks_glob[0]; $path =~ s/^\///;

my @to_paths;
open(my $fstab_fh, '<', "$disks_glob[0]/etc/fstab");
while(<$fstab_fh>) {
	chomp;
	next if m/^\s*#/;
	next unless m/ext[34]/;
	my ( $disk, $to, $fs, undef ) = split(/\s+/, $_, 4);
	push @to_paths, $to;
}
close($fstab_fh);

print "paths = @to_paths\n";

warn "ERROR: to_paths != disks_glob" unless $#to_paths == $#disks_glob;

open(my $zfs_snapshots, '-|', "zfs list -t snapshot -o name -H $path");
chomp(my @snapshots = <$zfs_snapshots>);
close($zfs_snapshots);

my $snapshot = $snapshots[-1];
if ( $restore_date ) {
	$snapshot = ( grep { m/$restore_date/ } @snapshots )[0];
	print "restore snapshot: $snapshot\n";
} else {
	print "last snapshot: $snapshot\n";
}

my (undef, $date) = split(/@/, $snapshot, 2);


my $clone = "zamd/clone/$instance-$date";

foreach my $from ( @disks_glob ) {
	$from =~ s{^/}{};
	my $to = shift @to_paths; $to =~ s{/$}{};
	my $cmd = "sudo zfs clone $from\@$date $clone$to";
	my $clone_exists = `zfs list -H -o name $clone$to`;
       	if ( ! $clone_exists ) {
		print "$cmd\n";
		system $cmd;
	} else {
		print "SKIP $cmd\n";
	}
}

warn "## remove acpid which conflicts with systemd-nspawn";
system "systemd-nspawn --directory /$clone apt-get remove -y acpid";

warn "## modify instance $clone";
system "/srv/zfs-tools/ganeti-instance-modify.pl /$clone";

warn "## add tsocks";
system "systemd-nspawn --directory /$clone apt-get install -y tsocks";
open(my $tsocks_fh, '>', "/$clone/etc/tsocks.conf");
print $tsocks_fh qq{
local = 193.198.212.0/255.255.252.0
local = 10.0.0.0/255.0.0.0

server = 193.198.212.255
server_type = 5
server_port = 1080
};
close($tsocks_fh);


print "# boot instance with:\n";
print "cd /$clone ; /srv/zfs-tools/ganeti-nspawn.sh --boot\n";

