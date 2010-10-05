use strict;
use warnings;
use 5.006; # Found with Perl::MinimumVersion

package Data::Serializable;
BEGIN {
  $Data::Serializable::VERSION = '0.40.1';
}
use Moose::Role;

# ABSTRACT: Moose role that adds serialization support to any class

use Class::MOP ();
use Carp qw(croak confess);

# Wrap data structure that is not a hash-ref
sub _wrap_invalid {
    my ($module, $obj) = @_;
    # JSON doesn't know how to serialize anything but hashrefs
    # FIXME: Technically we should allow array-ref, as JSON standard allows it
    if ( $module eq 'Data::Serializer::JSON' ) {
        return ref($obj) eq 'HASH' ? $obj : { '_serialized_object' => $obj };
    }
    # XML::Simple doesn't know the difference between empty string and undef
    if ( $module eq 'Data::Serializer::XML::Simple' ) {
        return { '_serialized_object_is_undef' => 1 } unless defined($obj);
        return $obj if ref($obj) eq 'HASH';
        return { '_serialized_object' => $obj };
    }
    return $obj;
}

# Unwrap JSON previously wrapped with _wrap_invalid()
sub _unwrap_invalid {
    my ($module, $obj) = @_;
    if ( $module eq 'Data::Serializer::JSON' ) {
        if ( ref($obj) eq 'HASH' and keys %$obj == 1 and exists( $obj->{'_serialized_object'} ) ) {
            return $obj->{'_serialized_object'};
        }
        return $obj;
    }
    # XML::Simple doesn't know the difference between empty string and undef
    if ( $module eq 'Data::Serializer::XML::Simple' ) {
        if ( ref($obj) eq 'HASH' and keys %$obj == 1 ) {
            if ( exists $obj->{'_serialized_object_is_undef'}
                and $obj->{'_serialized_object_is_undef'} )
            {
                return undef; ## no critic qw(Subroutines::ProhibitExplicitReturnUndef)
            }
            return $obj->{'_serialized_object'} if exists $obj->{'_serialized_object'};
            return $obj;
        }
        return $obj;
    }
    return $obj;
}


has 'throws_exception' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);


has "serializer_module" => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Storable',
);


has "serializer" => (
    is      => 'rw',
    isa     => 'CodeRef',
    lazy    => 1,
    builder => '_build_serializer',
);

# Default serializer uses Storable
sub _build_serializer { ## no critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)
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

    unless ( $module->isa('Data::Serializer') ) {
        confess("Serializer module '$module' is not a subclass of Data::Serializer");
    }
    my $handler = bless {}, $module; # subclasses apparently doesn't implement new(), go figure!
    unless ( $handler->can('serialize') ) {
        confess("Serializer module '$module' doesn't implement the serialize() method");
    }

    # Return the specified serializer if we know about it
    return sub {
        # Data::Serializer::* has an instance method called serialize()
        return $handler->serialize(
            _wrap_invalid( $module, $_[0] )
        );
    };

}


has "deserializer" => (
    is      => 'rw',
    isa     => 'CodeRef',
    lazy    => 1,
    builder => '_build_deserializer',
);

# Default deserializer uses Storable
sub _build_deserializer { ## no critic qw(Subroutines::ProhibitUnusedPrivateSubroutines)
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
            return if @_ > 0 and not defined( $_[0] );
            return ${ Storable::thaw( $_[0] ) };
        };
    }

    unless ( $module->isa('Data::Serializer') ) {
        confess("Serializer module '$module' is not a subclass of Data::Serializer");
    }
    my $handler = bless {}, $module; # subclasses apparently doesn't implement new(), go figure!
    unless ( $handler->can('deserialize') ) {
        confess("Serializer module '$module' doesn't implement the deserialize() method");
    }

    # Return the specified serializer if we know about it
    return sub {
        return if @_ > 0 and not defined( $_[0] );
        # Data::Serializer::* has an instance method called deserialize()
        return _unwrap_invalid(
            $module, $handler->deserialize( $_[0] )
        );
    };

}


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

no Moose::Role;
1;



=pod

=encoding utf-8

=head1 NAME

Data::Serializable - Moose role that adds serialization support to any class

=head1 VERSION

version 0.40.1

=head1 SYNOPSIS

    package MyClass;
    use Moose;
    with 'Data::Serializable';
    no Moose;

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

=head1 ATTRIBUTES

=head2 throws_exception

Defines if methods should throw exceptions or return undef. Default is to throw exceptions.
Override default value like this:

    has '+throws_expection' => ( default => 0 );

=head2 serializer_module

Name of a predefined module that you wish to use for serialization.
Any submodule of L<Data::Serializer> is automatically supported.
The built-in support for L<Storable> doesn't require L<Data::Serializer>.

=head2 serializer

If none of the predefined serializers work for you, you can install your own.
This should be a code reference that takes one argument (the message to encode)
and returns a scalar back to the caller with the serialized data.

=head2 deserializer

Same as serializer, but to decode the data.

=head1 METHODS

=head2 serialize($message)

Runs the serializer on the specified argument.

=head2 deserialize($message)

Runs the deserializer on the specified argument.

=head1 SEE ALSO

=over 4

=item *

L<Moose::Manual::Roles>

=item *

L<Data::Serializer>

=back

=for :stopwords CPAN AnnoCPAN RT CPANTS Kwalitee diff

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

  perldoc Data::Serializable

=head2 Websites

=over 4

=item *

Search CPAN

L<http://search.cpan.org/dist/Data-Serializable>

=item *

AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Data-Serializable>

=item *

CPAN Ratings

L<http://cpanratings.perl.org/d/Data-Serializable>

=item *

CPAN Forum

L<http://cpanforum.com/dist/Data-Serializable>

=item *

RT: CPAN's Bug Tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-Serializable>

=item *

CPANTS Kwalitee

L<http://cpants.perl.org/dist/overview/Data-Serializable>

=item *

CPAN Testers Results

L<http://cpantesters.org/distro/D/Data-Serializable.html>

=item *

CPAN Testers Matrix

L<http://matrix.cpantesters.org/?dist=Data-Serializable>

=item *

Source Code Repository

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<git://github.com/robinsmidsrod/Data-Serializable.git>

=back

=head2 Bugs

Please report any bugs or feature requests to C<bug-data-serializable at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-Serializable>.  I will be
notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 AUTHOR

Robin Smidsrød <robin@smidsrod.no>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Robin Smidsrød.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__

