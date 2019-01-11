#!/usr/bin/env perl

###### PACKAGES ######

use Getopt::Long;

###### PACKAGE CONFIG ######

Getopt::Long::Configure('no_ignore_case');
Getopt::Long::Configure('pass_through');

###### CONSTANTS ######

###### GLOBAL VARIABLES ######

use vars qw($Warn $Crit $Dir);

###### MAIN PROGRAM ######

parse_cmd_line();

chdir $Dir or die "failed to chdir to $Dir: $!";

my $cmd = "ls | tail -1 | xargs stat -c%Z";
my $curr_epoch = time;
my $stat_epoch = `$cmd`;
my $diff = $curr_epoch - $stat_epoch;

print "backup is $diff seconds old\n";

if ($diff > $Crit) {
	exit 2;
}
elsif ($diff > $Warn) {
	exit 1;
}

print "OK\n";
exit 0;

###### END MAIN ######

sub check_required {
    my $opt = shift;
    my $arg = shift;

    print_usage("missing arg $opt") if !$arg;
}

sub parse_cmd_line {
    my $help;

    my $rc = GetOptions(
        'c=s'    => \$Crit,
		'w=s'	 => \$Warn,
		'd=s'    => \$Dir,
        "help|?" => \$help
    );

    print_usage("usage:") if $help;

    check_required( '-c', $Crit );
	check_required( '-w', $Warn );
	check_required( '-d', $Dir);
}

sub print_usage {
    print STDERR "@_\n";

    print "\n$0\n"
	  . "\t-d <backup dir location>\n"
	  . "\t-w <warning age in secs>\n"
      . "\t-c <critical age in secs>\n"
      . "\t[-?] (usage)\n" . "\n";

    exit 1;
}
