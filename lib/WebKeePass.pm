package WebKeePass;
#ABSTRACT: Main loader class for the app

=head1 DESCRIPTION

This loads all the application routes

=cut

use Dancer 2.0;
use Carp 'croak'; 
use WebKeePass::DB;

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
    template 'unlock', { title => "Unlock", flash => flash() };
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
    template 'keepass' => { entries => $entries };
};

1;
