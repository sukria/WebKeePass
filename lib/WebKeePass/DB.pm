package WebKeePass::DB;
#ABSTRACT: module to access the KeePass database

=head1 DESCRIPTION

This module is here to wrap all the access knowledge to the KeePass database.

=cut

use Moo;
use Carp 'croak'; 
use File::KeePass;

=attr db_file 

The path to the KeePass DB file to handle

=cut

has db_file => (
    is => 'ro',
    required => 1,
);

=attr keepass

The File::KeePass object built with the db_file

=cut

has keepass => (
    is => 'rw',
    lazy => 1,
    builder => '_build_keepass',
);

sub _build_keepass { File::KeePass->new }

=method load_db

Method to open the DB file, with the master password.

=cut

sub load_db {
    my ($self, $master_password) = @_;
    $self->keepass->load_db($self->db_file, $master_password);    
    $self->keepass->unlock;
}


=method entries

Retreive all the entries in the DB that have a title, a username and a password

=cut

sub entries {
    my ($self) = @_;

    my $groups = $self->keepass->groups;
    my @entries;

    foreach my $group (map { $_->{groups} } @{ $groups }) {
        foreach my $entry (map { @{ $_->{entries} } } @{ $group }) {

            my ( $title, $username, $password ) =
              ( $entry->{title}, $entry->{username}, $entry->{password} );

            push @entries, {
                title => $title,
                username => $username,
                password => $password,
            } if defined $title && defined $username && defined $password;
        }
    }

    return \@entries;
}

1;
