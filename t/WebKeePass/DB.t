# DB.t

use strict;
use warnings;
use Test::More;
use File::Basename 'dirname';
use File::Spec;
use WebKeePass::DB;
use Data::Dumper;

my $db_file = File::Spec->rel2abs(
    File::Spec->catfile(dirname(__FILE__), '..', 'Test.kdbx'));
ok( -f $db_file, "$db_file exists");

my $db = WebKeePass::DB->new( db_file => $db_file );
isa_ok $db, 'WebKeePass::DB';

ok( $db->load_db('T3stDB'), "DB file opened with valid password");

my $entries = $db->entries;
is_deeply $entries,
  [
    {
        title    => 'Google Account',
        username => 'johnnywalker@gmail.com',
        password => 'ph32IklTK93ceV5TRe2U'
    },
    {
        title    => 'Twitter',
        username => 'johnnywalker',
        password => 'HmiEBZMBGeMDTAvFMVKE'
    },
    {
        title    => 'Facebook',
        username => 'johnny.walker',
        password => 'cvVYIICJ0qz5MIFiu5yd'
    },
    {
        title => 'Sample Entry',
        username => 'User Name',
        password => 'Password',
    },
    {
        title => 'Sample Entry #2',
        username => 'Michael321',
        password => '12345',
    },
  ],
  "Entries are fetched";

done_testing;
