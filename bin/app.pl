#!/usr/bin/env perl

use strict;
use warnings;

# PODNAME: app

BEGIN {
    use FindBin;

    while ( my $libdir = glob("${FindBin::Bin}/../vendor/*/lib") ) {
        unshift @INC, $libdir;
    }
}

use Dancer 2.0;
use WebKeePass;
dance;
