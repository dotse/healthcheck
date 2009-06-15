package Zonestat;

use 5.008008;
use strict;
use warnings;

use Zonestat::Config;
use Zonestat::Common;
use Zonestat::Prepare;
use Zonestat::Gather;
use Zonestat::Present;
use Zonestat::DBI;

our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    $self->{conf}    = Zonestat::Config->new(@_);
    $self->{prepare} = Zonestat::Prepare->new($self);
    $self->{gather}  = Zonestat::Gather->new($self);
    $self->{present} = Zonestat::Present->new($self);

    my $c = $self->cget("dbi");
    Zonestat::DBI::set_connection_data(
        sprintf(
            "DBI:mysql:database=%s;hostname=%s;port=%s",
            $c->{"database"}, $c->{"host"}, $c->{"port"}
        ),
        $c->{user},
        $c->{password}
    );

    return $self;
}

sub cget {
    my $self = shift;

    return $self->{conf}->get(@_);
}

sub prepare {
    my $self = shift;
    return $self->{prepare};
}

sub gather {
    my $self = shift;
    return $self->{gather};
}

sub present {
    my $self = shift;
    return $self->{present};
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
