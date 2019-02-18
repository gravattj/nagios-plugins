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

###### GLOBALS ######

use vars qw(
	$Host
	$Port
	$Service
);

###### MAIN ######

parse_cmd_line();

my @result = `/usr/bin/nmap -sU -p $Port -P0 $Host`;

foreach my $line (@result){
	chomp $line;
	if ($line =~ /^$Port/) {
		$line =~ s/\|/-/;
		my ($port, $state, $service) = split(/\s+/, $line);
		
		if (is_state_ok($state)) {
			if (is_service_ok($service)) {
				ok($line);
			}
			else {
				critical("service does not match: $Service != $service");	
			}
		}
		else {
			critical("port state: $state");		
		}
	}
}

critical("strange nmap output?");

###### END MAIN ######

sub ok {
	my $msg = shift;
	print "OK: $msg\n";
	exit 0;
}

sub critical {
	my $msg = shift;
	print "CRITICAL: $msg\n"	;
	exit 2;
}

sub is_state_ok {
	my $state = shift;
	
	if ($state =~ /open/) {
		return 1;	
	}	
	
	return 0;
}

sub is_service_ok {
	my $service = shift;
	
	if ($Service) {
		if ($Service ne $service) {
			return 0;	
		}
	}	
	
	return 1;
}

sub check_required {
    my $opt = shift;
    my $arg = shift;

    print_usage("missing arg $opt") if !$arg;
}

sub parse_cmd_line {
    my $help;

    GetOptions(
        "h=s"    => \$Host,
        "p=s" => \$Port,
        "s=s" => \$Service,
        "help|?" => \$help
    );

    print_usage("usage:") if $help;

    check_required( '-h', $Host );
    check_required('-p', $Port);

    if ( @ARGV != 0 ) {
        print_usage("parse_cmd_line failed");
    }
}

sub print_usage {
    print STDERR "@_\n";

    print <<"HERE";

$0    
    -h <host> 
    -p <port>
    -s <service>
    [-?] (usage)
     
HERE

    exit 1;
}
