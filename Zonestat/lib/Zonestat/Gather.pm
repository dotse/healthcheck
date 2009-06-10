package Zonestat::Gather;

use 5.008008;
use strict;
use warnings;

use DNSCheck;

use base 'Zonestat::Common';

our $VERSION = '0.01';

sub start_dnscheck_zone {
    my $self = shift;

    $self->dbh->do(
q[INSERT INTO queue (domain, priority, source_id) SELECT domain, 4, ? FROM domains ORDER BY rand()],
        undef, $self->get_dnscheck_source_id
    );
}

sub get_zone_list {
    my $self = shift;

    map { $_->[0] } @{
        $self->dbh->selectall_arrayref(
            q[SELECT domain FROM domains ORDER BY domain ASC])
      };
}

1;
__END__

=head1 NAME

Zonestat::Gather - gather statistics

=head1 SYNOPSIS

  use Zonestat::Gather;

=head1 DESCRIPTION


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
