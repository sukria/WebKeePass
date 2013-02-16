use strict;
use warnings;
use Test::More import => [ '!pass' ];

use Dancer;
set show_errors => 1;
set template => 'template_toolkit';

use File::Spec;
my $views = File::Spec->rel2abs(path(dirname(__FILE__), 'views'));
set views => $views;

use t::lib::App;
use Dancer::Test 't::lib::App';

response_content_is [GET => '/in_route'], "Bonjour";
response_content_is [GET => '/in_view'], "in view: Bonjour\n";

done_testing;
