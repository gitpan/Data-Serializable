package Data::Serializable;

use Moose::Role;

use Class::MOP ();
use Carp qw(croak confess);

use namespace::autoclean -also => [
    '_wrap_invalid',
    '_unwrap_invalid',
    '_build_serializer',
    '_build_deserializer',
];

=head1 NAME

Data::Serializable - Moose-based role that adds serialization support to any class

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    package MyClass;
    use Moose;
    with 'Data::Serializable';
    
    package main;
    my $obj = MyClass->new( serializer_module => 'JSON' );
    my $json = $obj->serialize( "Foo" );
    ...
    my $str = $obj->deserialize( $json );

=head1 DESCRIPTION

A Moose-based role that enables the consumer to easily serialize/deserialize data structures.
The default serializer is L<Storable>, but any serializer in the L<Data::Serializer> hierarchy can
be used automatically. You can even install your own custom serializer if the pre-defined ones
are not useful for you.

=head1 EXPORT

This is a Moose-based role. It doesn't export anything to normal perl modules.

=cut

sub _wrap_invalid {
    my ($module, $obj) = @_;
    if ( $module eq 'Data::Serializer::JSON' ) {
        return ref($obj) eq 'HASH' ? $obj : { '_serialized_object' => $obj };
    }
    return $obj;
}

sub _unwrap_invalid {
    my ($module, $obj) = @_;
    if ( $module eq 'Data::Serializer::JSON' ) {
        if ( ref($obj) eq 'HASH' and keys %$obj == 1 and exists($obj->{'_serialized_object'}) ) {
            return $obj->{'_serialized_object'};
        }
        return $obj;
    }
    return $obj;
}

=head1 ATTRIBUTES

=cut

=head2 throws_exception

Defines if methods should throw exceptions or return undef. Default is to throw exceptions.
Override default value like this:

    has '+throws_expection' => ( default => 0 );

=cut

has 'throws_exception' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

=head2 serializer_module

Name of a predefined module that you wish to use for serialization.
Any submodule of L<Data::Serializer> is automatically supported.
The built-in support for L<Storable> doesn't require L<Data::Serializer>.

=cut

has "serializer_module" => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Storable',
);

=head2 serializer

If none of the predefined serializers work for you, you can install your own.
This should be a code reference that takes one argument (the message to encode)
and returns a scalar back to the caller with the serialized data.

=cut

has "serializer" => (
    is      => 'rw',
    isa     => 'CodeRef',
    lazy    => 1,
    builder => '_build_serializer',
);

# Default serializer uses Storable
sub _build_serializer {
    my ($self) = @_;

    # Figure out full package name of serializer
    my $module = $self->serializer_module;
    if( $module ne 'Storable' ) {
        $module = 'Data::Serializer::' . $module;
    }
    
    # Make sure serializer module is loaded
    Class::MOP::load_class( $module );

    # Just return sub if using default
    if ( $module eq 'Storable' ) {
        return sub {
            return Storable::nfreeze( \( $_[0] ) );
        };
    }

    # Return the specified serializer if we know about it
    if ( $module->can('serialize') ) {
        return sub {
            # Data::Serializer::* has a static method called serialize()
            return $module->serialize(
                _wrap_invalid( $module, $_[0] )
            );
        };
    }
    
    confess("Unsupported serializer specified");
}

=head2 deserializer

Same as serializer, but to decode the data.

=cut

has "deserializer" => (
    is      => 'rw',
    isa     => 'CodeRef',
    lazy    => 1,
    builder => '_build_deserializer',
);

# Default deserializer uses Storable
sub _build_deserializer {
    my ($self) = @_;

    # Figure out full package name of serializer
    my $module = $self->serializer_module;
    if( $module ne 'Storable' ) {
        $module = 'Data::Serializer::' . $module;
    }
    
    # Make sure serializer module is loaded
    Class::MOP::load_class( $module );

    # Just return sub if using default
    if ( $module eq 'Storable' ) {
        return sub {
            return ${ Storable::thaw( $_[0] ) };
        };
    }
    
    # Return the specified serializer if we know about it
    if ( $module->can('deserialize') ) {
        return sub {
            # Data::Serializer::* has a static method called deserialize()
            return _unwrap_invalid(
                $module, $module->deserialize( $_[0] )
            );
        };
    }
    
    confess("Unsupported deserializer specified");
}

=head1 METHODS

=head2 serialize($message)

Runs the serializer on the specified argument.

=cut

sub serialize {
    my ($self,$message) = @_;

    # Serialize data
    my $serialized = eval { $self->serializer->($message); };
    if ($@) {
        croak("Couldn't serialize data: $@") if $self->throws_exception;
        return; # FAIL
    }

    return $serialized;
}

=head2 deserialize($message)

Runs the deserializer on the specified argument.

=cut

sub deserialize {
    my ($self,$message)=@_;

    # De-serialize data
    my $deserialized = eval { $self->deserializer->($message); };
    if ($@) {
        croak("Couldn't deserialize data: $@") if $self->throws_exception;
        return; # FAIL
    }

    return $deserialized;
}

=head1 AUTHOR

Robin Smidsrød, C<< <robin at smidsrod.no> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-data-serializable at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-Serializable>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::Serializable


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-Serializable>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-Serializable>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Data-Serializable>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-Serializable/>

=back


=head1 COPYRIGHT & LICENSE

Copyright 2009 Robin Smidsrød

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Moose::Manual::Roles>, L<Data::Serializer>

=cut

1; # End of Data::Serializable
