#!/usr/bin/perl
use strict;
use warnings;

require 5.008_000;

use Term::ANSIColor qw/colored :constants/;

my $reset = RESET;
my $style_int = GREEN;
my $style_null = CYAN;
my $style_date = YELLOW;
my $style_header = UNDERLINE;
my $style_row = MAGENTA;
# my $style_date = YELLOW . ON_BLUE; # << combinaison example

my ($term_cols, $term_lines) = (0, 0);

# Try to determine the screen size from module or stty
eval {
    require "Term/ReadKey.pm";
    ($term_cols, $term_lines) = Term::ReadKey::GetTerminalSize();
} or eval {
    ($term_lines, $term_cols) = split /\s+/, `stty -F /dev/stderr size`;
};

# Global print "buffer" scalar and filehandle
my $outhandle;
my $outstring = "";

open($outhandle, "+>", \$outstring)
    or die("Can't create temporary buffer");

select($outhandle);
END {
    # If less was used, then outstring will be empty
    print STDOUT $outstring;
}

my $input_format = ""; # unknown by default;

# First line with +---+-----+ or ******
my $header = <>;

if ( $header =~ /^\+(?:-+\+)+$/ ) {
    $input_format = "std";
    print $header;
} elsif ( $header =~ /^\*+/ ) {
    $input_format = "vertical";
    print $style_row, $header, $reset;
} else {
    print $header;
}

my $match_null = qr/(?:^NULL\s*)|(?:\s*NULL$)/; # XXX rewrite?
my $match_int  = qr/^\s*-?\d+\.?\d*$/;
my $match_date = qr/^(?:[0-9]{4}-[0-9]{2}-[0-9]{2})|(?:[0-9]{2}:[0-9]{2}:[0-9]{2})/;

my $date = '\d{4}-\d{2}-\d{2}';
my $time = '\d{2}:\d{2}:\d{2}';

# Quick max function :p
sub max(@) { (sort @_)[-1] }

my $useless = !(-t STDOUT) || undef;
my $cur_cols = length($header);
my $cur_lines = scalar(grep /\n/, $outstring);

while (my $line = <>) {
    if ( ! $useless ) {
        $cur_lines++;
        $cur_cols = max($cur_cols, length($line));

        if ( $cur_lines > $term_lines || $cur_cols - 1 > $term_cols) {
            # Switch to less, and write current buffer
            open($useless, '| less -R -S')
                or die("Can't open less");
            select($useless);

            print $useless $outstring;
            close($outhandle);
            $outstring = "";
        }
    }

    if ( $input_format eq "std" ) {
        $line =~ s/\| +\K(NULL +)(?=\|)/$style_null$1$reset/g;
        $line =~ s/\| +\K(-?\d+\.?\d* )(?=\|)/$style_int$1$reset/g;
        $line =~ s/\| \K((?:$date(?: $time)?|(?:$date )?$time) +)(?=\|)/$style_date$1$reset/g;
    } elsif ( $input_format eq "vertical" ) {
        $line =~ s/^((\*{27}) \d+\..*? \*{27})/$style_row$1$reset/;

        $line =~ s/^ *\K(\S+)(?=: )/$style_header$1$reset/;

        $line =~ s/: \K(NULL)$/$style_null$1$reset/ ||
        $line =~ s/: \K(-?\d+\.?\d*)$/$style_int$1$reset/ ||
        $line =~ s/: \K((?:$date(?: $time)?|(?:$date )?$time))$/$style_date$1$reset/;
    }

    print $line;
}
