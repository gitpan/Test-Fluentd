#!perl -w
use strict;
use Test::More tests => 1;

BEGIN {
    use_ok 'Test::Fluentd';
}

diag "Testing Test::Fluentd/$Test::Fluentd::VERSION";
