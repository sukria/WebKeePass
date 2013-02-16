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
        id       => 3,
        title    => 'Facebook',
        username => 'johnny.walker',
        password => 'cvVYIICJ0qz5MIFiu5yd'
    },
    {
        id       => 1,
        title    => 'Google Account',
        username => 'johnnywalker@gmail.com',
        password => 'ph32IklTK93ceV5TRe2U'
    },
    {
        id       => 4,
        title => 'Sample Entry',
        username => 'User Name',
        password => 'Password',
    },
    {
        id       => 5,
        title => 'Sample Entry #2',
        username => 'Michael321',
        password => '12345',
    },
    {
        id       => 2,
        title    => 'Twitter',
        username => 'johnnywalker',
        password => 'HmiEBZMBGeMDTAvFMVKE'
    },

  ],
  "Entries are fetched";

is_deeply $db->stats,
  {
    version        => 2,
    last_modified  => '2013-02-16 14:38:08',
    key_updated_at => '2013-02-16 14:36:52',
    name           => 'Test Database KeePass2',
    entries        => 5,
    generator      => 'KeePass',
    cipher         => 'aes',
    encoding       => 'rijndael',
  },
  "stats look fine";

done_testing;
