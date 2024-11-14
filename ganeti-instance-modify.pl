#!/usr/bin/perl
use warnings;
use strict;
use autodie;
#use Data::Dump qw(dump);

my $clone = $ARGV[0] || die "Usage: $0 /zamd/clone/koha*-2023-10-27\n";
die "$clone ERROR $!" unless -e $clone;
my $date = $1 if $clone =~ m/(\d\d\d\d-\d\d-\d\d)/;

warn "# clone $clone date $date\n";

sub append_to {
	my ($path,$what) = @_;
	my $full_path = "$clone/$path";
	my $fh;
	my $allready_done = 0;
	if ( ! -e $full_path ) {
		print "WARNING $full_path doesn't exists, skipping adding $what\n";
		open($fh, '>', $full_path);
	} else {
		open($fh, '<', $full_path);
		while(<$fh>) {
			$allready_done = 1 if m/\Q$what\E/;
		}
		close($fh);
	}
	if ( ! $allready_done ) {
		open($fh, '>>', $full_path);
		print $fh $what . "\n";
		close($fh);
		print "MODIFIED $full_path $what\n";
	}
}

foreach my $path ( qw(
	root/.bashrc
	home/dpavlin/.bashrc
) ) {

append_to $path => 'export http_proxy=http://193.198.212.255:8888';
append_to $path => 'export https_proxy=http://193.198.212.255:8888';
append_to $path => 'PS1="'.$date.' $PS1"';

}

sub comment_line {
	my ( $path, $pattern ) = @_;
	$path = "$clone/$path";
	open(my $i, '<', $path);
	open(my $o ,'>', $path . '.new');
	my @found;
	while(<$i>) {
		if ( m/$pattern/ && ! m/^#/ ) {
			print "# $path $pattern commented $_";
			push @found, $_;
			s/^/#/;
		}
		print $o $_;
	}
	close($i);
	close($o);
	if ( @found ) {
		warn "# $path modified\n";
		rename $path . '.new' => $path;
	}
	#warn "## comment_line $path $pattern =( @found )\n";
	return join("\n", @found);
}

# comment out nfs and cifs filesystems in /etc/fstab
comment_line "/etc/fstab" => '(nfs|cifs)';

if ( comment_line "/etc/resolv.conf" => '^nameserver 193.198.212.8' ) {
	append_to    "/etc/resolv.conf" => 'nameserver 193.198.212.255';
}
if ( comment_line '/etc/resolv.conf' => '^nameserver 10.20.0.200' ) {
	append_to    "/etc/resolv.conf" => 'nameserver 10.21.0.254';
}

# disable IPv6 inside container so that our http ipv4 proxy works
#append_to '/etc/sysctl.conf' => 'net.ipv6.conf.all.disable_ipv6 = 1';
