package Zonestat::Present;

use 5.008008;
use strict;
use warnings;

use base 'Zonestat::Common';

our $VERSION = '0.01';

sub lame_delegated_domains {
    my $self = shift;

    return (
        (
            $self->dbh->selectrow_array(
q[select count(distinct(test_id)) from results where message = 'NAMESERVER:NOT_AUTH']
            )
        )[0]
    );
}

sub number_of_domains_with_message {
    my $self = shift;
    my $message = shift || 'ERROR';

    return @{
        $self->dbh->selectall_arrayref(
q[SELECT message, COUNT(DISTINCT(test_id)) AS cdt FROM results WHERE level = ? GROUP BY message ORDER BY cdt DESC],
            undef, $message
        )
      };
}

1;
__END__

=head1 NAME

Zonestat::Present - present gathered statistics

=head1 SYNOPSIS

  use Zonestat::Present;

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
