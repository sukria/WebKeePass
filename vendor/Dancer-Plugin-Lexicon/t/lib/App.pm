package t::lib::App;
use strict;
use warnings;

BEGIN {
    use Dancer ':syntax';
    config()->{'plugins'} = {
        Lexicon =>  {
            namespace => 'foo',
            path => "t/languages",
            default => "fr",
            func => ['l'],
        }
    };
}

use Dancer::Plugin::Lexicon;

if (int(dancer_version) == 2) {
    dp_lexicon_install_hooks();
}

get '/in_route' => sub {
    l('hello'); 
};

get '/in_view' => sub {
    template 'test';   
};

1;
