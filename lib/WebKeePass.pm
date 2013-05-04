package WebKeePass;
#ABSTRACT: Main loader class for the app

=head1 DESCRIPTION

This loads all the application routes

=cut

use Dancer 2.0;
use Carp 'croak'; 
use WebKeePass::DB;
use Dancer::Plugin::Ajax;

sub flash {
    my ($message) = @_;
    if (@_) {
        session flash => $message;
    }
    else {
        my $message = session('flash');
        session flash => undef;
        return $message;
    }
}

hook before_template_render => sub {
    my ($tokens) = @_;
    $tokens->{entries} = session('entries');
    $tokens->{stats} = session('stats');
    $tokens->{flash} = flash(),
};

get '/' => sub {
    if (defined session('entries')) {
        return redirect '/keepass';
    }

    template 'unlock', { title => "Home" }; 
};

post '/keepass' => sub {
    my $password = param('password');
    if (! $password) {
        flash "Please provide the master password of the database";
        return redirect '/';
    }

    my $keepass_file = setting('application')->{'db_file'};
    my $keepass = WebKeePass::DB->new( db_file => $keepass_file );
    eval { $keepass->load_db($password) };
    if ($@) {
        flash "Unable to open DB: $@";
        return redirect '/';
    }

    session entries => $keepass->entries;
    session stats   => $keepass->stats;
    my $title = $keepass->entries->[0]->{title};

    redirect "/keepass/$title";
};

get '/keepass/**' => sub {
    if (! defined session('entries')) {
        flash('You need to unlock the database to access this page.');
        return redirect '/';
    }

    my @splat = splat;
    my $path = $splat[0];
    my $db = session('entries');

    my $group = WebKeePass::DB->get_group_by_path($db, @{ $path });

use Data::Dumper;
warn Dumper($group);
warn "===> ".join(' / ', @$path);


    my $navbar = [];
    my $prefix = '/keepass';
    foreach my $path (@{ $path }) {
        push @{ $navbar },
          {
            name => $path,
            link => "$prefix/$path",
          };
          $prefix .= "/$path";
    }
    $navbar->[-1]->{is_last} = 1;

    if (! defined $group) {
        return send_error "Not Found", 404;
    }

    template 'keepass' => {
        title  => session('stats')->{'name'},
        group  => $group,
        navbar => $navbar,
    };
};

get '/signout' => sub {
    context->destroy_session;
    redirect '/';
};

post '/password' => sub {
    my $id = param('entry');
    my $entry = WebKeePass::DB->entry_by_id(session('entries'), $id);
    content_type 'application/json';

    if (! defined $entry) {
        status 403;
        return to_json({error => "session closed"});
    }

    status 200;
    to_json({password => $entry->{password}});
};

1;
