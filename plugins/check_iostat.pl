#!/usr/bin/env perl

###### PACKAGES ######

use strict;
use warnings;
use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');

###### CONSTANTS ######

use constant EXIT_OK        => 0;
use constant EXIT_WARNING   => 1;
use constant EXIT_CRITICAL  => 2;
use constant EXIT_UNKNOWN   => 3;
use constant EXIT_DEPENDENT => 4;

use constant WARNING_DEFAULT  => 9999999;
use constant CRITICAL_DEFAULT => 9999999;

# rhel 6 headers
# Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await  svctm  %util
# rhel 7 headers
# Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util

use constant DEVICE         => 'Device:';
use constant READ_PER_SEC   => 'rkB/s';
use constant WRITE_PER_SEC  => 'wkB/s';
use constant AVG_REQ_SIZE   => 'avgrq-sz';
use constant AVG_QUEUE_SIZE => 'avgqu-sz';
use constant AVG_WAIT_MS    => 'await';
use constant UTILIZATION    => '%util';

###### GLOBALS ######

use vars qw(
    $ReadPerSec
    $WritePerSec
    $AvgReqSize
    $AvgQueueSize
    $AvgWait
    $Util
    $IncludeRegex
    $ExcludeRegex
    $PerfFlag
    @Headers
    $Warnings
    $Criticals
    $Verbose 
    %Perf
);

###### MAIN ######

parse_cmd_line();
main();

if ($Criticals) {
    printf "%s\n", get_perf_data();
    exit EXIT_CRITICAL;
}
elsif ($Warnings) {
    printf "%s\n", get_perf_data();
    exit EXIT_WARNING;
}
else {
    printf "OK %s\n", get_perf_data();
    exit EXIT_OK;
}

###### END MAIN ######

sub main {

    my $cmd   = 'iostat -dkxy 5 1';
    my @stdin = `$cmd`;

    foreach my $line (@stdin) {

        next if is_blank($line);
        chomp $line;

        if ( !@Headers ) {
            if ( $line =~ /^Device:/ ) {
                @Headers = split( /\s+/, $line );
                print "$line\n" if $Verbose;
            }
        }
        else {
            check_device($line);
        }
    }
}

sub get_perf_data {
    
    my $ret = '';
    
    if ($PerfFlag) {
   
        $ret = '| ';
         
        foreach my $dev (sort keys %Perf) {
       
            my $metrics_href = $Perf{$dev};
             
            foreach my $metric (sort keys %$metrics_href) {
            
                $ret.= sprintf "%s_%s=%s; ", $dev, $metric, $metrics_href->{$metric};
            }    
        }
    }
    
    return $ret;
}

sub check_device {

    my $line = shift;

    my @values = split( /\s+/, $line );
    my $dev = get_value( DEVICE, \@values );

    if ( want_dev($dev) ) {

        print "$line\n" if $Verbose;
        check_threshold( READ_PER_SEC,  $ReadPerSec,  $dev, get_value( READ_PER_SEC,  \@values ) );
        check_threshold( WRITE_PER_SEC, $WritePerSec, $dev, get_value( WRITE_PER_SEC, \@values ) );
        check_threshold( AVG_REQ_SIZE,  $AvgReqSize,  $dev, get_value( AVG_REQ_SIZE,  \@values ) );
        check_threshold( AVG_QUEUE_SIZE, $AvgQueueSize, $dev,
            get_value( AVG_QUEUE_SIZE, \@values ) );
        check_threshold( AVG_WAIT_MS, $AvgWait, $dev, get_value( AVG_WAIT_MS, \@values ) );
        check_threshold( UTILIZATION, $Util,    $dev, get_value( UTILIZATION, \@values ) );
    }
}

sub want_dev {

    my $dev = shift;

    if ($IncludeRegex) {

        if ( $dev =~ /$IncludeRegex/ ) {
            return 1;
        }
    }

    if ($ExcludeRegex) {

        if ( $dev =~ /$ExcludeRegex/ ) {
            return 0;
        }
        else {
            return 1;
        }
    }

    return 1;
}

BEGIN {

    my %thresholds;

    sub check_threshold {

        my $header  = shift;
        my $cutoffs = shift;
        my $dev     = shift;
        my $val     = shift;

        my $warn;
        my $crit;

        if ( !defined $thresholds{$header} ) {

            ( $warn, $crit ) = get_warn_crit_values($cutoffs);

            $thresholds{$header} = {
                warn => $warn,
                crit => $crit
            };
        }
        else {

            $warn = $thresholds{$header}->{warn};
            $crit = $thresholds{$header}->{crit};
        }

        if ( $val >= $crit ) {
            log_critical( $dev, $header, $val, $crit );
        }
        elsif ( $val >= $warn ) {
            log_warning( $dev, $header, $val, $warn );
        }
        
        $Perf{$dev}->{$header} = $val;
    }
}

sub log_warning {

    my ( $dev, $header, $val, $cutoff ) = @_;

    $Warnings++;
    print "WARN: $dev $header threshold=$cutoff value=$val\n";
}

sub log_critical {

    my ( $dev, $header, $val, $cutoff ) = @_;

    $Criticals++;
    print "CRIT: $dev $header $val >= $cutoff\n";
}

sub get_warn_crit_values {

    my $val = shift;

    my $warn = WARNING_DEFAULT;
    my $crit = CRITICAL_DEFAULT;

    if ( defined $val ) {

        my ( $w, $c ) = split( /,/, $val );
        $warn = $w if defined $w;
        $crit = $c if defined $c;
    }

    if ( $warn > $crit ) {
        die "warning threshold can't be greater than critical threshold: $val\n";
    }

    return ( $warn, $crit );
}

sub get_value {

    my $header      = shift;
    my $values_aref = shift;

    for ( my $i = 0; $i < @Headers; $i++ ) {

        if ( $Headers[$i] eq $header ) {
            return $values_aref->[$i];
        }
    }

    die "failed to find value for $header";
}

sub is_blank {

    my $val = shift;

    if ( $val =~ /^\s*$/ ) {
        return 1;
    }

    return 0;
}

sub check_required {
    my $opt = shift;
    my $arg = shift;

    print_usage("missing arg $opt") if !$arg;
}

sub parse_cmd_line {
    my $help;

    my $rc = GetOptions(
        "rs=s"       => \$ReadPerSec,
        "ws=s"       => \$WritePerSec,
        "avgrq-sz=s" => \$AvgReqSize,
        'avgqu-sz=s' => \$AvgQueueSize,
        'await=s'    => \$AvgWait,
        'util=s'     => \$Util,
        'i=s'        => \$IncludeRegex,
        'e=s'        => \$ExcludeRegex,
        'perf'       => \$PerfFlag,
        'v'          => \$Verbose,
        "help|?"     => \$help
    );

    print_usage("usage:") if $help;

    #check_required( '-h', $Host );

    if ( !($rc) || ( @ARGV != 0 ) ) {
        print_usage("parse_cmd_line failed");
    }
}

sub print_usage {
    print STDERR "@_\n";

    print STDERR <<'HERE';
$0 <args...>

    [ -rs       <warnkb,critkb> ] (rkB/s)
    [ -ws       <warnkb,critkb> ] (wkB/s)
    [ -avgrq-sz <warn,crit> ]
    [ -avgqu-sz <warn,crit> ]
    [ -await    <warn,crit> ]
    [ -util     <warn,crit> ]

    [-e <exclude device regex>] 
    [-i <include device regex>] (used to trump -e)
    [-perf] (print performance metrics)
    [-v]    (verbose output)
    [-?]    (usage)
HERE

    exit 1;
}
