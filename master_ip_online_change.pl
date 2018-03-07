#!/usr/bin/env perl

#  Copyright (C) 2011 DeNA Co.,Ltd.
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#  Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

## Note: This is a sample script and is not complete. Modify the script based on your environment.

use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use MHA::DBHelper;
use MHA::NodeUtil;
use Time::HiRes qw( sleep gettimeofday tv_interval );
use Data::Dumper;

my $_tstart;
my $_running_interval = 0.1;
my (
  $command,              $orig_master_is_new_slave, $orig_master_host,
  $orig_master_ip,       $orig_master_port,         $orig_master_user,
  $orig_master_password, $orig_master_ssh_user,     $new_master_host,
  $new_master_ip,        $new_master_port,          $new_master_user,
  $new_master_password,  $new_master_ssh_user,
);
my $dr_vip = '10.1.13.250';
my $rs_vip = '10.1.13.250';
my $lvs1 = '10.1.13.17';
my $lvs2 = '10.1.13.18';
my $ssh_user = 'root';
GetOptions(
  'command=s'                => \$command,
  'orig_master_is_new_slave' => \$orig_master_is_new_slave,
  'orig_master_host=s'       => \$orig_master_host,
  'orig_master_ip=s'         => \$orig_master_ip,
  'orig_master_port=i'       => \$orig_master_port,
  'orig_master_user=s'       => \$orig_master_user,
  'orig_master_password=s'   => \$orig_master_password,
  'orig_master_ssh_user=s'   => \$orig_master_ssh_user,
  'new_master_host=s'        => \$new_master_host,
  'new_master_ip=s'          => \$new_master_ip,
  'new_master_port=i'        => \$new_master_port,
  'new_master_user=s'        => \$new_master_user,
  'new_master_password=s'    => \$new_master_password,
  'new_master_ssh_user=s'    => \$new_master_ssh_user,
);

exit &main();



sub main {

    if ( $command eq "stop" || $command eq "stopssh" ) {
        my $exit_code = 1;
        eval {
            print "Remove RS - $orig_master_ip - on DR $rs_vip\n";
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
            print "Add RS - $new_master_host - on DR $rs_vip\n";
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
  `ssh $ssh_user\@$lvs1 \"ipvsadm --delete-server -t $dr_vip:$orig_master_port -r $orig_master_ip:$orig_master_port\"`;
  `ssh $ssh_user\@$lvs2 \"ipvsadm --delete-server -t $dr_vip:$orig_master_port -r $orig_master_ip:$orig_master_port\"`;
}


sub usage {
  print
"Usage: master_ip_online_change --command=start|stop|status --orig_master_host=host --orig_master_ip=ip --orig_master_port=port --new_master_host=host --new_master_ip=ip --new_master_port=port\n";
  die;
}

