#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use File::Basename qw(dirname);
use Cwd qw(abs_path);

# Read only the existing log messages. No simulator plugin or Perl package
# outside the standard installation is required
my ($devices, $width, $unit, $help, $standard);
GetOptions('devices=i' => \$devices, 'width=i' => \$width,
           'unit=s' => \$unit, 'help' => \$help,
           'standard' => \$standard) or die "Invalid options\n";
if ($help || !@ARGV) {
    print "Usage: perl report.pl [--standard] [--devices N --width W --unit ps] run.log [packets.csv]\n";
    print "N/W are read from config.txt beside the log when available.\n";
    print "--unit is required only if printed timestamps have no suffix.\n";
    print "Default: Excel Spanish (semicolon separator, decimal comma).\n";
    print "--standard: comma separator and decimal point for GNUplot.\n";
    exit($help ? 0 : 1);
}
my ($log, $csv) = @ARGV;
die "Expected one log and an optional output CSV\n" if @ARGV > 2;
$csv //= dirname($log) . '/packets.csv';
die "Output cannot overwrite the input log\n"
    if -e $csv && abs_path($csv) eq abs_path($log);

my $config = dirname($log) . '/config.txt';
if (-f $config) {
    open my $cfg, '<', $config or die "Cannot read $config: $!\n";
    while (<$cfg>) {
        $devices //= $1 if /^N=(\d+)/;
        $width //= $1 if /^W=(\d+)/;
    }
    close $cfg;
}
die "Specify --devices N or provide config.txt\n" unless defined $devices;
die "Specify --width W or provide config.txt\n" unless defined $width;
die "Devices must be between 2 and 10\n" unless $devices >= 2 && $devices <= 10;
die "Width must be 16, 32 or 64\n" unless $width == 16 || $width == 32 || $width == 64;
my %scale = (s => 1e9, ms => 1e6, us => 1e3, ns => 1, ps => 1e-3, fs => 1e-6);
die "Unknown time unit '$unit'\n" if defined $unit && !exists $scale{lc $unit};

sub time_ns {
    my ($stamp) = @_;
    $stamp =~ /^\s*(\d+(?:\.\d+)?)\s*(s|ms|us|ns|ps|fs)?\s*$/i
        or die "Unrecognized timestamp [$stamp]\n";
    my ($value, $suffix) = ($1, $2);
    $suffix = defined $suffix ? lc $suffix : $unit;
    die "Timestamp [$stamp] has no unit; use --unit ns or --unit ps\n"
        unless defined $suffix;
    return $value * $scale{lc $suffix};
}

sub packet_hex {
    my ($hex) = @_;
    $hex = lc $hex;
    $hex =~ s/^0x//;
    $hex =~ s/_//g;
    die "Packet exceeds configured width: $hex\n" if length($hex) > $width / 4;
    return ('0' x ($width / 4 - length($hex))) . $hex;
}

sub destination {
    my ($packet) = @_;
    my $header = substr($packet, 0, 2); # Eight MSB, without converting 64-bit payloads to integers
    return $header =~ /[xz]/ ? '' : hex($header);
}

my (@requests, @pending, @rows);
my ($pops, $pushes) = (0, 0);
open my $input, '<', $log or die "Cannot read $log: $!\n";
while (my $line = <$input>) {
    # Generator metadata supplies the original ID and requested gap
    if ($line =~ /generator:\s*transaction\s+(\d+)\s+generated\s*-\s*src=(\d+)\s+dst=(\d+)\s+broadcast=([01])\s+gap=(\d+)\s+payload=0x([0-9a-fxz_]+)/i) {
        my ($id, $source, $dst, $broadcast, $gap, $payload) = ($1, $2, $3, $4, $5, $6);
        my $payload_digits = $width / 4 - 2;
        $payload =~ s/_//g;
        my $packet = sprintf('%02x', $dst) . substr(('0' x $payload_digits) . lc($payload), -$payload_digits);
        push @{$requests[$source]}, {
            transaction_id => $id, source => $source, destination => $dst,
            packet => '0x' . $packet, gap_cycles => $gap, ambiguous => 0,
        };
        next;
    }

    # Use monitor events only. Checker/driver messages are not additional
    # transfers and must not be counted twice
    next unless $line =~ /^\[([^\]]+)\]\s*Monitor\s*\[(\d+)\]:\s*(POP|PUSH)\s+observed,\s*packet=0x([0-9a-fxz_]+)/i;
    my ($stamp, $port, $event, $hex) = ($1, $2, uc($3), $4);
    my $time = time_ns($stamp);
    my $packet = packet_hex($hex);
    my $dst = destination($packet);

    if ($event eq 'POP') {
        $pops++;
        my $request = shift @{$requests[$port] //= []};
        my %base = (
            source => $port, destination => $dst, packet => '0x' . $packet,
            send_time_ns => $time, status => 'pending', ambiguous => 0,
        );
        if ($request) {
            $base{transaction_id} = $request->{transaction_id};
            $base{gap_cycles} = $request->{gap_cycles};
            $base{input_matches_request} = ($request->{packet} eq $base{packet}) ? 1 : 0;
        }

        if ($port >= $devices || $dst eq '') {
            $base{status} = 'invalid_input';
            push @rows, \%base;
            next;
        }
        if ($dst >= $devices && $dst != 255) {
            $base{status} = 'discard_expected';
            push @rows, \%base;
            next;
        }
        my @receivers = $dst == 255 ? grep { $_ != $port } 0 .. $devices - 1 : ($dst);
        for my $receiver (@receivers) {
            my %delivery = (%base, receiver => $receiver);
            # Retain the ambiguity mark for both copies, even after the
            # first matching delivery is removed from the pending queue
            for my $older (@{$pending[$receiver] //= []}) {
                if ($older->{packet} eq $delivery{packet}) {
                    $older->{ambiguous} = 1;
                    $delivery{ambiguous} = 1;
                }
            }
            my $row = \%delivery;
            push @rows, $row;
            push @{$pending[$receiver]}, $row;
        }
    }
    else {
        $pushes++;
        my $queue = $pending[$port] //= [];
        my $index;
        for my $i (0 .. $#$queue) {
            if ($queue->[$i]{packet} eq '0x' . $packet) { $index = $i; last; }
        }
        if (defined $index) {
            my ($row) = splice @$queue, $index, 1;
            $row->{receive_time_ns} = $time;
            $row->{latency_ns} = $time - $row->{send_time_ns};
            die "Reception precedes POP in the log\n" if $row->{latency_ns} < 0;
            $row->{status} = 'received';
        }
        else {
            push @rows, {
                destination => $dst, receiver => $port, packet => '0x' . $packet,
                receive_time_ns => $time, status => 'unexpected', ambiguous => 0,
            };
        }
    }
}
close $input;

# Originals that were generated but never observed at POP have no send time
# Do not invent a send time from generation (usually everything was generated at 0)
for my $queue (@requests) {
    next unless $queue;
    for my $request (@$queue) {
        push @rows, { %$request, status => 'not_accepted' };
    }
}
die "No recognizable packet messages in $log\n" unless @rows;

my @columns = qw(transaction_id source destination receiver packet send_time_ns
                 receive_time_ns latency_ns gap_cycles status ambiguous input_matches_request);
open my $output, '>', $csv or die "Cannot write $csv: $!\n";
binmode($output);
my $separator = $standard ? ',' : ';';
my $newline = $standard ? "\n" : "\r\n";
# Excel reads this first line to select the delimiter on double-click.
# Decimal comma matches the user's Spanish regional settings.
print {$output} 'sep=;', $newline unless $standard;
print {$output} join($separator, @columns), $newline;
for my $row (@rows) {
    my @values;
    for my $column (@columns) {
        my $value = $row->{$column} // '';
        if ($column =~ /_ns$/ && $value ne '') {
            $value = sprintf('%.6f', $value);
            $value =~ s/\./,/ unless $standard;
        }
        $value =~ s/"/""/g;
        push @values, '"' . $value . '"';
    }
    print {$output} join($separator, @values), $newline;
}
close $output;
my $ambiguous = scalar grep { $_->{ambiguous} } @rows;
print "CSV: $csv; observed POP=$pops PUSH=$pushes; rows=" . scalar(@rows) . "\n";
warn "Ambiguous rows=$ambiguous: source/ID/latency use the first matching pending copy\n" if $ambiguous;
warn "No POP events observed; generated originals have no measured send time\n" unless $pops;
