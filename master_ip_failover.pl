#!/usr/bin/env perl

# force_shutdown_internal
# $dead_master->{master_ip_failover_script} --orig_master_host=$dead_master->{hostname} --orig_master_ip=$dead_master->{ip} --orig_master_port=$dead_master->{port}

# recover_master
# $new_master->{master_ip_failover_script} --command=start --ssh_user=$new_master->{ssh_user} --orig_master_host=$dead_master->{hostname} --orig_master_ip=$dead_master->{ip} --orig_master_port=$dead_master->{port} --new_master_host=$new_master->{hostname} --new_master_ip=$new_master->{ip} --new_master_port=$new_master->{port} --new_master_user=$new_master->{escaped_user} --new_master_password=$new_master->{escaped_password}


use strict;
use warnings FATAL => 'all';


use Getopt::Long;
use MHA::DBHelper;
my (
    $command,
    $ssh_user,
    $orig_master_host,
    $orig_master_ip,
    $orig_master_port,
    $new_master_host,
    $new_master_ip,
    $new_master_port,
);
my $dr_vip = '10.1.13.250';
my $rs_vip = '10.1.13.250';
my $lvs1 = '10.1.13.17';
my $lvs2 = '10.1.13.18';

GetOptions(
    'command=s'          => \$command,
    'ssh_user=s'         => \$ssh_user,
    'orig_master_host=s' => \$orig_master_host,
    'orig_master_ip=s'   => \$orig_master_ip,
    'orig_master_port=i' => \$orig_master_port,
    'new_master_host=s'  => \$new_master_host,
    'new_master_ip=s'    => \$new_master_ip,
    'new_master_port=i'  => \$new_master_port,
    'help|h|?'           => \&usage
);

exit &main();


sub main {

    if ( $command eq "stop" || $command eq "stopssh" ) {
        my $exit_code = 1;
        eval {
            print "Remove RS - $orig_master_ip - on DR $lvs1\nRemove RS - $orig_master_ip - on DR $lvs2\n";
            &del_rs();
            $exit_code = 0;
        };
        if ($@) {
            warn "Got Error: $@\n";
            exit $exit_code;
        }
        exit $exit_code;
    }

    
    elsif ( $command eq "start" ) {
        my $exit_code = 10;
        eval {
            print "Add RS - $new_master_host - on DR $lvs1\nAdd RS - $new_master_host - on DR $lvs2\n";
            &add_rs();
            $exit_code = 0;
        };
        if ($@) {
            warn $@;
            exit $exit_code;
        }
        exit $exit_code;
    }
    
    elsif ( $command eq "status" ) {
        print "Checking the Status of the script.. OK \n";
        exit 0;
    }
    
    else {
        &usage();
    }
}


sub add_rs() { 
    # add new master as RS
    `ssh $ssh_user\@$lvs1 \"ipvsadm --add-server -t $dr_vip:$orig_master_port -r $new_master_ip:$new_master_port --gatewaying\"`;
    `ssh $ssh_user\@$lvs2 \"ipvsadm --add-server -t $dr_vip:$orig_master_port -r $new_master_ip:$new_master_port --gatewaying\"`;
}

sub del_rs() { 
  # delete old RS
  `ssh $ssh_user\@$lvs1 \"ipvsadm --delete-server -t $dr_vip:$orig_master_port -r $orig_master_ip:$orig_master_port\"`;
  `ssh $ssh_user\@$lvs2 \"ipvsadm --delete-server -t $dr_vip:$orig_master_port -r $orig_master_ip:$orig_master_port\"`;
}

sub usage {
    print
    "Usage: 
        master_ip_failover --command=start|stop|stopssh|status 
        --orig_master_host=host --orig_master_ip=ip --orig_master_port=port 
        --new_master_host=host --new_master_ip=ip --new_master_port=port
        [--help|-h]\n";
    exit 1;
}



