#!/usr/bin/env perl

# vim: tabstop=4 expandtab

###### PACKAGES ######

use strict;
use warnings;
use Proc::ProcessTable;
use Data::Printer alias => 'pdump';
use String::Util 'trim';

use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');

###### CONSTANTS ######

use constant LIMIT_MAP => (
    cpu        => 'Max cpu time',
    fsize      => 'Max file size',
    data       => 'Max data size',
    stack      => 'Max stack size',
    core       => 'Max core file size',
    rss        => 'Max resident set',
    nproc      => 'Max processes',
    nofile     => 'Max open files',
    memlock    => 'Max locked memory',
    as         => 'Max address space',
    locks      => 'Max file locks',
    sigpending => 'Max pending signals',
    msgqueue   => 'Max msgqueue size',
    nice       => 'Max nice priority',
    priority   => 'Max realtime priority',
    rtprio     => 'Max realtime timeout',
);

=pod
     - maxlogins - max number of logins for this user
     - maxsyslogins - max number of logins on the system
=cut

=pod

Max cpu time              unlimited            unlimited            seconds 

limit =  0..24
soft  = 26..45
hard  = 47..66

=cut

###### GLOBALS ######

use vars qw(
  $Exec
  $Item
  $Soft
  $Hard
);

###### MAIN ######

parse_cmd_line();

my $proc_table = Proc::ProcessTable->new;
my @procs      = @{ $proc_table->table };
my $want       = map_limit_string();

my @errors;

foreach my $p (@procs) {

    if ( $p->fname and $p->fname eq $Exec ) {

        my $limit_file = sprintf "/proc/%d/limits", $p->pid;

        open my $fh, $limit_file or die "failed to open $limit_file: $!";

        my $header = 1;

        while ( my $rec = <$fh> ) {

            if ($header) {
                $header = 0;
                next;
            }

            my ( $name, $soft, $hard ) = parse_rec($rec);

            if ( $name eq $want ) {

                my $softeq = $soft eq $Soft ? '=' : '!=';
                my $hardeq = $hard eq $Hard ? '=' : '!=';

                my $msg = sprintf "$Item soft%s$Soft hard%s$Hard   (pid:%d)",
                  $softeq, $hardeq, $p->pid;

                if ( $soft ne $Soft or $hard ne $Hard ) {
                    myerror($msg);
                }
                else {
                    ok($msg);
                }
            }
        }
    }
}

exit 0;

###### END MAIN ######

sub ok {
    my @msg = @_;
    my $msg = "@msg";
    chomp $msg;

    print "OK - $msg\n";
}

sub myerror {
    my @msg = @_;
    my $msg = "@msg";

    print "ERROR - $msg\n";
    exit 1;
}

sub parse_rec {

    my $rec = shift;

    chomp $rec;
    my $name = trim( substr( $rec, 0,  24 ) );
    my $soft = trim( substr( $rec, 26, 19 ) );
    my $hard = trim( substr( $rec, 47, 19 ) );

    return ( $name, $soft, $hard );
}

sub map_limit_string {

    my @map = LIMIT_MAP();
    my %map = @map;

    if ( $map{$Item} ) {
        return $map{$Item};
    }

}

sub check_required {
    my $opt = shift;
    my $arg = shift;

    print_usage("missing arg $opt") if !$arg;
}

sub parse_cmd_line {
    my $help;

    GetOptions(
        "e=s"    => \$Exec,
        "i=s"    => \$Item,
        "s=s"    => \$Soft,
        "h=s"    => \$Hard,
        "help|?" => \$help
    );

    print_usage("usage:") if $help;

    check_required( '-e', $Exec );
    check_required( '-i', $Item );
    check_required( '-s', $Soft );
    check_required( '-h', $Hard );

    #    if (!defined $Soft and !defined $Hard) {
    #        print_usage("must provide -s and/or -h");
    #    }

    if ( @ARGV != 0 ) {
        print_usage("parse_cmd_line failed");
    }
}

sub print_usage {
    print STDERR "@_\n";

    print <<"HERE";

$0   
    -e <exec>         (ie: mongod)
    -i <limit item>   (see below)
    [-s <soft limit>]
    [-h <hard limit>] 
    [-?] (usage)
    
   <item> can be one of the following:
     - core - limits the core file size (KB)
     - data - max data size (KB)
     - fsize - maximum filesize (KB)
     - memlock - max locked-in-memory address space (KB)
     - nofile - max number of open file descriptors
     - rss - max resident set size (KB)
     - stack - max stack size (KB)
     - cpu - max CPU time (MIN)
     - nproc - max number of processes
     - as - address space limit (KB)
     - maxlogins - max number of logins for this user
     - maxsyslogins - max number of logins on the system
     - priority - the priority to run user process with
     - locks - max number of file locks the user can hold
     - sigpending - max number of pending signals
     - msgqueue - max memory used by POSIX message queues (bytes)
     - nice - max nice priority allowed to raise to values: [-20, 19]
     - rtprio - max realtime priority
     
HERE

    exit 3;
}
