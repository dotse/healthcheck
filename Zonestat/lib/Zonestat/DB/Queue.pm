package Zonestat::DB::Queue;

use base 'Zonestat::DB::Common';

sub length {
    my $self = shift;
    
    my $db = $self->db('zonestat-queue');
    
    return $db->countDocs - 1; # We have one design document.
}

1;