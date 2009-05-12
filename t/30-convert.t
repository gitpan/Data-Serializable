#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 3;

package MyClass;
use Moose;
with 'Data::Serializable';
#has '+throws_exception' => ( default => 0 );

package main;
my $obj = MyClass->new();
my $str = "Test";
my $array = [ qw( a b c ) ];
my $hash = { a => "b", c => "d" };
my $str_conv = $obj->deserialize($obj->serialize($str));
my $array_conv = $obj->deserialize($obj->serialize($array));
my $hash_conv = $obj->deserialize($obj->serialize($hash));
is( $str_conv, $str, 'string serialization/deserialization fails' );
is_deeply( $array_conv, $array, 'arrayref serialization/deserialization fails' );
is_deeply( $hash_conv, $hash, 'hashref serialization/deserialization fails' );
