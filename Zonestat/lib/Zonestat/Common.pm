package Zonestat::Common;

use 5.008008;
use strict;
use warnings;

use DBI;

our $VERSION = '0.01';
my $source_id_string  = q[Zonestat];
my $source_id_contact = q[calle@init.se];

sub new {
    my $class = shift;
    return bless { parent => shift }, $class;
}

sub parent {
    my $self = shift;

    return $self->{parent};
}

sub cget {
    my $self = shift;

    return $self->{parent}->cget(@_);
}

sub dbh {
    my $self = shift;

    return $self->{dbh} if (defined($self->{dbh}) and $self->{dbh}->ping);

    my $dbh = DBI->connect($self->parent->dbconfig, { RaiseError => 1, AutoCommit => 1 });
    die "Failed to connect to database: " . $DBI::errstr . "\n"
      unless defined($dbh);
    $self->{dbh} = $dbh;
    return $dbh;
}

sub source_id {
    my $self = shift;

    if (!defined($self->parent->{source_id})) {
        my $dbh = $self->dbh;

        $dbh->do(q[INSERT IGNORE INTO source (name, contact) VALUES (?,?)],
            undef, $source_id_string, $source_id_contact);
        $self->parent->{source_id} = (
            (
                $dbh->selectrow_array(
                    q[SELECT id FROM source WHERE name = ?], undef,
                    $source_id_string
                )
            )[0]
        );
    }
    return $self->parent->{source_id};
}

sub set_run_id {
    my $self = shift;

    $self->parent->{run_id} = $_[0];
}

sub run_id {
    my $self = shift;

    if (!defined($self->parent->{run_id})) {
        my $tmp = (
            $self->dbh->selectrow_array(
                q[
            SELECT MAX(source_data) FROM tests WHERE source_id = ?
            ], undef, $self->source_id
            )
        )[0];
        $self->parent->{run_id} = ++$tmp;
    }

    return $self->parent->{run_id};
}

1;
__END__

=head1 NAME

Zonestat::Common - parent module for the worker modules.

=head1 SYNOPSIS

  use base 'Zonestat::Common';

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
