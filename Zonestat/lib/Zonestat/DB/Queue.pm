package Zonestat::DB::Queue;

use warnings;
use strict;
use utf8;

use base 'Zonestat::DB::Common';

## no critic (Subroutines::ProhibitBuiltinHomonyms)
sub length {
    my $self = shift;

    my $db = $self->db( 'zonestat-queue' );

    return $db->countDocs - 1;    # We have one design document.
}

1;
