package WebKeePass;
#ABSTRACT: Main loader class for the app

=head1 DESCRIPTION

This loads all the application routes

=cut

use Dancer 2.0;
use Carp 'croak'; 

get '/' => sub {
    "WebKeePass";
};

1;
