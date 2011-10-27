package Zonestat::DB::Asdata;

use warnings;
use strict;
use utf8;
use Try::Tiny;

use base 'Zonestat::DB::Common';

## no critic (Subroutines::RequireFinalReturn)
# Something about this method confuses Perl::Critic.
sub asn2name {
    my ( $self, $asn ) = @_;

    my $db  = $self->db( 'zonestat-asdata' );
    my $doc = $db->newDoc( $asn );
    try {
        $doc->retrieve;
        return $doc->data->{asname};
    }
    catch {
        if ( /Object not found/ ) {
            return;
        }
        else {
            die( $_ );
        }
    }
}

1;

=head1 NAME

Zonestat::DB::Asdata - database interface class for the ASN database

=head1 SYNOPSIS

my $as = Zonestat->new->asdata;

=head1 DESCRIPTION

=head2 Methods

=over

=item asn2name($asn)

Takes an AS number and returns its name, if it can be found in the database.
Returns C<undef> if not.

=back
