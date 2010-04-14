use inc::Module::Install 0.95;

name     'Data-Serializable';
author   'Robin Smidsrød <robin@smidsrod.no>';
license  'perl';
all_from 'lib/Data/Serializable.pm';

requires 'Carp'                 => 0;
requires 'Class::MOP'           => 0;
requires 'Moose::Role'          => 0;
requires 'Storable'             => 0;
requires 'namespace::autoclean' => 0;

test_requires 'Test::More'      => 0;
test_requires 'JSON'            => 0;
test_requires 'Data::Serializer::JSON' => 0;
test_requires 'Moose'           => 0;

WriteAll;

