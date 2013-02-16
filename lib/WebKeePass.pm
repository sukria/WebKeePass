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

get '/' => sub {
    if (defined session('entries')) {
        return redirect '/keepass';
    }

    template 'unlock', { 
        title => "Unlock", 
        need_unlocking => 1,
        flash => flash() };
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

    my $entries = $keepass->entries;
    session entries => $entries;

    template 'keepass' => { entries => $entries };
};

get '/keepass' => sub {
    if (! defined session('entries')) {
        flash('You need to unlock the database first');
        return redirect '/';
    }
    template 'keepass' => { entries => session('entries') };
};

get '/signout' => sub {
    context->destroy_session;
    redirect '/';
};

sub entry_by_id {
    my ($entries, $id) = @_;
    for my $e (@{ $entries }) {
        return $e if $e->{id} == $id;
    }
    return undef;
}

post '/password' => sub {
    my $id = param('entry');
    my $entry = entry_by_id(session('entries'), $id);
    content_type 'application/json';

    if (! defined $entry) {
        status 403;
        return to_json({error => "session closed"});
    }

    status 200;
    to_json({password => $entry->{password}});
};

1;
