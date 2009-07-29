package Zonestat::Present;

use 5.008008;
use strict;
use warnings;

use base 'Zonestat::Common';

our $VERSION = '0.01';

sub total_tested_domains {
    my $self = shift;

    return (
        (
            $self->dbh->selectrow_array(
                q[SELECT COUNT(DISTINCT(domain)) FROM tests])
        )[0]
    );
}

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

sub number_of_servers_with_software {
    my $self = shift;
    my ($https) = @_;

    my $s = $self->dbx('Webserver');
    return map { [$_->type, $_->get_column('count')] } $s->search(
        { https => $https },
        {
            select   => ['type', { count => '*' }],
            as       => ['type', 'count'],
            group_by => ['type'],
            order_by => ['count(*) DESC'],
        }
    )->all;
}

sub unknown_server_strings {
    my $self = shift;

    my $s = $self->dbx('Webserver');
    return map { $_->raw } $s->search({ type => 'Unknown' },
        { columns => ['raw'], distinct => 1, order_by => ['raw'] })->all;
}

sub all_dnscheck_tests {
    my $self = shift;

    my $s = $self->dbx('Tests');
    return $s->search({}, { order_by => ['domain'] });
}

sub all_domainsets {
    my $self = shift;

    my $s = $self->dbx('Domainset');
    return $s->search({}, { order_by => ['name'] });
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
