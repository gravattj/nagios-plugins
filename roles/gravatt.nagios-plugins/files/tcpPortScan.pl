#!/usr/bin/env perl

# vim: tabstop=4 expandtab

###### PACKAGES ######

use Modern::Perl;
use Data::Printer alias => 'pdump';
use Getopt::Long;
Getopt::Long::Configure('no_ignore_case');
use Util::Medley::Spawn;
use Monitoring::Plugin;

###### CONSTANTS ######

###### GLOBALS ######

use vars qw(
  $ExpectedPorts $Host $Spawn $CheckAllPorts $Plugin
);

###### MAIN ######

parseCmdLine();

$Spawn  = Util::Medley::Spawn->new;
$Plugin = Monitoring::Plugin->new;

main();

###### END MAIN ######

sub main {
	my @cmd;
	push @cmd, ( 'nice', 'nmap', '-sT' );
	push @cmd, "-p 1-65535" if $CheckAllPorts;
	push @cmd, $Host;

	my ( $stdoutAref, $stderrAref, $exit ) = runScan();
	if ($exit) {
		my $stderr = join ' ', @$stderrAref;
		$Plugin->plugin_exit( UNKNOWN,
			"nmap failed: [cmd: @cmd] [exit: $exit] [stderr: $stderr]" );
	}

	my @expected = split( /,/, $ExpectedPorts );
	my %expected = map { $_ => 1 } @expected;

	my @found = parseOpenPorts($stdoutAref);
	my %found = map { $_ => 1 } @found;

	my %errorClosed;
	foreach my $expected (@expected) {
		if ( !$found{$expected} ) {
			$errorClosed{$expected} = 1;
		}
	}

	my %errorOpen;
	foreach my $found (@found) {
		if ( !$expected{$found} ) {
			$errorOpen{$found} = 1;
		}
	}

	my $msg = getMessageV4( \%expected, \%found, \%errorClosed, \%errorOpen );

	my $status = OK;

	if ( keys %errorClosed ) {
		$status = WARNING;
	}

	if ( keys %errorOpen ) {
		$status = CRITICAL;
	}

	$Plugin->plugin_exit( $status, $msg );
}

sub getMessageV2 {
	my ( $expected, $found, $errorClosed, $errorOpen ) = @_;

	my @msg;
	push @msg, sprintf "open: [%s]", join( ',', @$found );

	if ( join( ',', @$expected ) ne join( ',', @$found ) ) {
		push @msg, sprintf "expected: [%s]", join( ',', @$expected );
	}

	return join( ' ', @msg );
}

sub getMessageV3 {
	my ( $expected, $found, $errorClosed, $errorOpen ) = @_;

	my @msg;
	push @msg, sprintf "open: [%s]", join( ',', @$found );

	if ( keys %$errorClosed ) {
		my @sorted = sort { $a <=> $b } keys %$errorClosed;
		push @msg, sprintf "missing: [%s]", join( ',', @sorted );
	}

	if ( keys %$errorOpen ) {
		my @sorted = sort { $a <=> $b } keys %$errorOpen;
		push @msg, sprintf "extra: [%s]", join( ',', @sorted );
	}

	return join( ' ', @msg );
}

sub getMessageV4 {
    
    my ( $expected, $found, $errorClosed, $errorOpen ) = @_;

    my @expected = sort {$a <=> $b } keys %$expected;
    
    my @msg;
    push @msg, sprintf "allowed:[%s]", join(',', @expected);
   
    my @actual;
    push @actual, keys %$found, keys %$errorClosed;
    @actual = sort {$a<=>$b} @actual;
    
    my @found;
    foreach my $port (@actual) {
        if ($errorClosed->{$port}) {
            push @found, "(-$port)";
        } 	
        elsif ($errorOpen->{$port}) {
            push @found, "(+$port)";	
        }
        else {
            push @found, $port;	
        }
    }
    
    push @msg, sprintf "found:[%s]", join( ',', @found );

    return join( ' ', @msg );
}

sub getMessageV1 {

	my ( $expected, $found, $errorClosed, $errorOpen ) = @_;

	my @msg;
	push @msg, sprintf "open: [%s]", join( ',', @$found );

	my @errors;
	push @errors, keys %$errorClosed;
	push @errors, keys %$errorOpen;

	if (@errors) {
		@errors = sort { $a <=> $b } @errors;

		my @diff;
		foreach my $err (@errors) {
			if ( $errorClosed->{$err} ) {
				push @diff, "-$err";
			}
			elsif ( $errorOpen->{$err} ) {
				push @diff, "+$err";
			}
			else {
				die "should not get here!";
			}
		}

		push @msg, sprintf "errors: [%s]", join( ',', @diff );
	}
	
	return join( ' ', @msg );
}

sub parseOpenPorts {
	my $aref = shift;

	my @found;
	foreach my $line (@$aref) {
		if ( $line =~ /^(\d+)\/\w/ ) {
			push @found, $1;
		}
	}

	return @found;
}

sub runScan {

	my @cmd;
	push @cmd, 'nice';
	push @cmd, 'nmap';
	push @cmd, '-sT';
	push @cmd, "-p 1-65535" if $CheckAllPorts;
	push @cmd, $Host;

	my ( $stdout, $stderr, $exit );
	eval {
		( $stdout, $stderr, $exit ) =
		  $Spawn->capture( cmd => \@cmd, wantArrayRef => 1, );
	};
	if (@$) {
		$stderr = [$@];
		$exit   = 255;
	}

	return ( $stdout, $stderr, $exit );
}

sub checkRequired {
	my $opt = shift;
	my $arg = shift;

	printUsage("missing arg $opt") if !$arg;
}

sub parseCmdLine {
	my $help;

	GetOptions(
		"h=s"             => \$Host,
		"p=s"             => \$ExpectedPorts,
		'check-all-ports' => \$CheckAllPorts,
		"help|?"          => \$help
	);

	printUsage("usage:") if $help;

	$ExpectedPorts = "" if !defined $ExpectedPorts;

	#    checkRequired( '-p', $ExpectedPorts );

	if ( @ARGV != 0 ) {
		printUsage("parseCmdLine failed");
	}
}

sub printUsage {
	print STDERR "@_\n";

	print <<"HERE";

$0   
    -h <host|ip> 
    [-p <comma separated list of expected ports>]
    [--check-all-ports]   (scan range 1 through 65535)
    [-?] (usage)
     
HERE

	exit 1;
}
