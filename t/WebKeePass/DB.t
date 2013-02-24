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
is_deeply $entries, [
{
    title   => 'Test',
    entries => [],
    group   => [
        {
            title   => "Nested Groups",
            entries => [],
            group   => [
                {
                    title   => "First",
                    entries => [
                        {
                            title    => "some entry",
                            password => 's3cr3t',
                            username => 'foo',
                            id => 'fc0994b845c593a9b188c565c1f258a97ca2d8d6',
                        }
                    ],
                    group => [
                        {
                            title => "Second",
                            group => [],
                            entries => [
                                {
                                    title => "entry1",
                                    password => 'PIKoUFbJpyCCpnC30E4E',
                                    id => 'cf2808679f1d5b093f8c57f2694f0b9fb4009015',
                                    username => "foo1",
                                },
                                {
                                    title => "entry2",
                                    password => "1C8zsCcZlSmxqArasLha",
                                    username => "foo2",
                                    id => "efbc03b7128b5f69af88ad8c5d65b080c7f9950c",
                                },
                            ],
                        },
                    ],
                },
            ],
        },
        {
            title   => "Internet",
            group   => [],
            entries => [
                {
                    'password' => 'ph32IklTK93ceV5TRe2U',
                    'title'    => 'Google Account',
                    'id'       => 'e138c7a403f3fcc4bb7e8eed945225e3596d0f64',
                    'username' => 'johnnywalker@gmail.com'
                },
                {
                    'password' => 'HmiEBZMBGeMDTAvFMVKE',
                    'title'    => 'Twitter',
                    'id'       => '04610ec4168b0ac8a80db1eb19f492f3220d038b',
                    'username' => 'johnnywalker'
                },
                {
                    'password' => 'cvVYIICJ0qz5MIFiu5yd',
                    'title'    => 'Facebook',
                    'id'       => 'd572701f5a6969f6c3e862981dbeff1f56addf82',
                    'username' => 'johnny.walker'
                },
            ],
        },

          ]
      }
      ], "entries are parsed correclty";

is_deeply $db->stats,
  {
    version        => 2,
    last_modified  => '2013-02-24 15:13:05',
    key_updated_at => '2013-02-16 14:36:52',
    name           => 'Test Database KeePass2',
    entries        => 6,
    generator      => 'KeePass',
    cipher         => 'aes',
    encoding       => 'rijndael',
  },
  "stats look fine";

done_testing;
