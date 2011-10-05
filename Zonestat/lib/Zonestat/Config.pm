package Zonestat::Config;

use 5.008008;
use strict;
use utf8;
use warnings;

use Config::Any;
use Data::Dumper;

our $VERSION = '0.2';

sub new {
    my ( $class, @files ) = @_;
    my $overrides;

    if ( @files == 1 ) {
        my $tmp = Config::Any->load_files( { files => [ $files[0] ], use_ext => 1, flatten_to_hash => 1 } );
        $overrides = $tmp->{ $files[0] };
    }
    else {
        $overrides = {@files};
    }

    my $self = {};
    bless $self, $class;

    $self->deepcopy( $self, $overrides );

    return $self;
}

sub get {
    my ( $self, @keys ) = @_;

    while ( @keys ) {
        my $k = shift @keys;
        $self = $self->{$k};
    }

    return $self;
}

sub set {
    my ( $self, $val, @keys ) = @_;

    while ( @keys > 1 ) {
        my $k = shift @keys;
        $self = $self->{$k};
    }

    return $self->{ $keys[0] } = $val;
}

# Helper methods

sub deepcopy {
    my ( $self, $target, $source ) = @_;

    while ( my ( $k, $v ) = each %$source ) {
        if ( ( !ref( $v ) ) || ( ref( $v ) ne 'HASH' ) ) {
            $target->{$k} = $v;
        }
        elsif (( !defined( $target->{$k} ) )
            || ( !ref( $target->{$k} ) )
            || ( ref( $target->{$k} ) ne 'HASH' ) )
        {
            $target->{$k} = {};
            $self->deepcopy( $target->{$k}, $v );
        }
        else {
            $self->deepcopy( $target->{$k}, $v );
        }
    }

    return;
}

1;

=head1 NAME

Zonestat::Config - handle configuration tasks for Zonestat modules

=head1 SYNOPSIS

  use Zonestat::Config;

=head1 DESCRIPTION

=over

=item ->new([filename | opthash])

The C<new()> method creates a config object. It will read a default
configuration from data included with the module, and override those defaults
with data specified in the call, if any. The specification can be done by
either providing a single filename argument, or an even number of arguments in
C<key =<gt> value> form. If it is a file name, the specified file will be read
and parsed as YAML.

=item ->get(@keylist)

Given a list of keys descending down through the configuration structure, this
method will return the stored value.

=item ->set($value, @keylist)

Given a value and a list of keys descending through the configuration
structure, this method will set the value for the given key to the given
value.

=back

=head1 EXAMPLES

  my $conf = Zonestat::Config->new(dbi => {password => 'gazonk'});
  print $conf->get('dbi','host');
  $conf->set('zonestat', qw[dbi username]);

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

__DATA__
