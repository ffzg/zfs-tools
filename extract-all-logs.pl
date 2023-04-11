#!/usr/bin/perl
use warnings;
use strict;
use autodie;

# interate through all snapshots and extract all logs from logrotate

use POSIX qw(strftime);
use Data::Dump qw(dump);

my $snapshots_path = 'zamd/oscar-zfs/mudrac';

my $log_glob = '/var/log/mail.log-*';

my $clone_to = "zamd/clone/log-clone";

my $log_to = "/zamd/clone/log/";
mkdir $log_to unless -d $log_to;

my @snapshots = map { chomp; $_ } `zfs list -t snapshot -r -o name -H $snapshots_path`;

print "# snapshots = ",dump( \@snapshots );

my $count = 0;

while ( my $snapshot = pop @snapshots ) {
	system "zfs clone $snapshot $clone_to";

	my @logs = sort { $b cmp $a } glob "/$clone_to/$log_glob";

	foreach my $file ( @logs ) {

		my $ctime = (stat($file))[10];
		my $date = strftime("%Y-%m-%d", localtime($ctime));

		my $to_path = $file;
		$to_path =~ s{.*/([^/]+)}{$1};
		#$to_path = "$log_to/$date.$to_path";
		$to_path = "$log_to/$to_path";

		if ( ! -e $to_path ) {
			system "cp -pv $file $to_path";
		} else {
			print "SKIP $file $to_path exists\n";
		}

		if ( @snapshots && $snapshots[-1] =~ m/$date/ ) {
			#warn "# remove $snapshots[-1]";
			pop @snapshots;
		}
	
	}

	system "zfs destroy $clone_to";

}

