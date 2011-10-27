package Zonestat::DB;

use strict;
use utf8;
use warnings;

use base 'Zonestat::Common';
use Carp;

sub new {
    my $class  = shift;
    my $parent = shift;
    my $self   = $class->SUPER::new( $parent );
    $self->{name} = shift;

    $self->initialize;

    return $self;
}

sub name {
    my $self = shift;

    return $self->{name};
}

sub db {
    my $self = shift;
    my $name = shift || $self->name;

    return $self->SUPER::db( $name );
}

sub initialize {
    my $self  = shift;
    my $ddocs = $self->db->listDesignDocs;

    foreach my $ddoc ( @{$ddocs} ) {
        $ddoc->retrieve;
        my $docname = $ddoc->id;
        $docname =~ s|_design/||;
        foreach my $view ( $ddoc->listViews ) {
            $self->{ $docname . '_' . $view } = sub {
                return $ddoc->queryView( $view, @_ );
              }
        }
    }

    return;
}

our $AUTOLOAD;

## no critic (Subroutines::RequireArgUnpacking)
sub AUTOLOAD {
    my $self = shift;
    my $view = $AUTOLOAD;

    $view =~ s|^.*:([^:]+)$|$1|;
    if ( $view eq 'DESTROY' ) {
        return;
    }
    elsif ( $self->{$view} ) {

        # Do the call here instead of defining the called method, since we want the
        # methods to act like they're specific to the object.
        return $self->{$view}->( @_ );
    }
    else {
        croak "No such view: $view";
    }
}

1;

=head1 NAME

Zonestat::DB - parent module for database interface classes

=head1 SYNOPSIS

use base 'Zonestat::DB';

=head1 DESCRIPTION

This module implements the automatic creation of Perl methods from CouchDB design documents.

=head1 SEE ALSO

L<Zonestat>.

=head1 AUTHOR

Calle Dybedahl, E<lt>calle@init.seE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Calle Dybedahl

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.9 or,
at your option, any later version of Perl 5 you may have available.

=cut