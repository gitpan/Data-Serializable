use inc::Module::Install 0.87;

name     'Data-Serializable';
all_from 'lib/Data/Serializable.pm';
author   'Robin Smidsrød <robin@smidsrod.no>';
license  'perl';

requires 'Carp'                 => 0;
requires 'Class::MOP'           => 0;
requires 'Moose::Role'          => 0;
requires 'Storable'             => 0;
requires 'namespace::autoclean' => 0;

test_requires 'Test::More'      => 0;
test_requires 'JSON'            => 0;
test_requires 'Moose'           => 0;

WriteAll;

