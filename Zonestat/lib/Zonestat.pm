package Zonestat;

use 5.008008;
use strict;
use warnings;

our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $self = bless {}, $class;
}

1;
__END__

=head1 NAME

Zonestat - gather and present statistics for a DNS zone

=head1 SYNOPSIS

  use Zonestat;

=head1 DESCRIPTION


=head1 SEE ALSO

L<DNSCheck>.

=head1 AUTHOR

Calle Dybedahl, E<lt>calle@init.seE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Calle Dybedahl

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.9 or,
at your option, any later version of Perl 5 you may have available.


=cut
