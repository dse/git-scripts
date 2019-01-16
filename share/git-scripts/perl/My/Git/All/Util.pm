package My::Git::All::Util;
use warnings;
use strict;
use v5.10.0;

use base 'Exporter';
our @EXPORT_OK = ('spork');

sub spork(&) {
    my ($sub) = @_;
    my $pid = fork;
    if (!defined $pid) {
        die("fork: $!\n");
    }
    if (!$pid) {
        $sub->();
        exit;
    }
    return $pid;
}

1;
