package My::Git::All::Term;
use warnings;
use strict;
use v5.10.0;

use base 'Exporter';
our @EXPORT_OK = ('isVT');

sub isVT {
    my $fileno = shift;
    $fileno //= 1;
    return if ! -t $fileno;
    return unless defined $ENV{TERM};
    return 1 if $ENV{TERM} =~ m{^vt};
    return 1 if $ENV{TERM} =~ m{^xterm};
    return 1 if $ENV{TERM} =~ m{^linux};
    return 1 if $ENV{TERM} =~ m{^screen};
    return 1 if $ENV{TERM} =~ m{^putty};
    return;
}

1;
