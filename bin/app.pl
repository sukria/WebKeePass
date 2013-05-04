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

use Dancer2;
use WebKeePass;
dance;
