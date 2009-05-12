#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 9;

package MyClass;
use Moose;
with 'Data::Serializable';

package main;
my $obj = MyClass->new();

# Private methods
ok($obj->can('_wrap_invalid'), '_wrap_invalid is not private');
ok($obj->can('_unwrap_invalid'), '_unwrap_invalid is not private');
ok($obj->can('_build_serializer'), '_build_serializer is not private');
ok($obj->can('_build_deserializer'), '_build_deserializer is not private');

# Public methods
ok($obj->can('serializer_module'), 'serializer_module not visible');
ok($obj->can('serializer'), 'serializer not visible');
ok($obj->can('deserializer'), 'deserializer not visible');
ok($obj->can('serialize'), 'serialize not visible');
ok($obj->can('deserialize'), 'deserialize not visible');
