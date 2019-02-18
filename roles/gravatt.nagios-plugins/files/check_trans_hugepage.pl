#!/usr/bin/env perl

# vim: tabstop=4 expandtab

###### PACKAGES ######

use strict;
use warnings;
use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 1;

###### CONSTANTS ######

use constant ENABLED_DEFAULT => 'always';
use constant ENABLED_OPTIONS => qw(always madvise never);
use constant SYSFS_PATH => '/sys/kernel/mm/transparent_hugepage/enabled';

###### GLOBALS ######

use vars qw(
    $Enabled
);

###### MAIN ######

parse_cmd_line();

my $curr = get_enabled_value();

if ($curr eq $Enabled) {
    print "$curr\n";
    exit 0;    
}
else {
    print "ERROR - expected '$Enabled', but found $curr\n";
    exit 1;    
}

###### END MAIN ######

sub get_enabled_value {
   
    my $cmd = sprintf "cat %s", SYSFS_PATH;
    my $out = `$cmd`;
    chomp $out;
    my @opts = split(/\s+/, $out);
    
    foreach my $o (@opts) {
        if ($o =~ /\[(\w+)\]/) {
            return $1;    
        }    
    }
    
    die "unable to find braces in sysfs file";
}

sub check_required {
    my $opt = shift;
    my $arg = shift;

    print_usage("missing arg $opt") if !$arg;
}

sub parse_cmd_line {
    my $help;

    GetOptions(
        "e=s"    => \$Enabled,
        "help|?" => \$help
    );

    print_usage("usage:") if $help;

    #check_required( '-s', $State );
    
    if (!defined $Enabled) {
        $Enabled = ENABLED_DEFAULT;    
    }
    
    my @opts = ENABLED_OPTIONS();
    my @match = grep { /^$Enabled$/ } @opts;
    
    if (@match != 1) {
        print_usage("unknown -e arg: $Enabled");    
    }
         
    if ( @ARGV != 0 ) {
        print_usage("parse_cmd_line failed");
    }
}

sub print_usage {
    print STDERR "@_\n";

    print <<"HERE";

$0    
    [-e <always|madvise|never>] (enabled default is 'always')
    [-?] (usage)
     
HERE

    exit 1;
}
