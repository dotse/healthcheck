package Statweb::Model::DB;

use strict;
use warnings;

use base qw/Catalyst::Model::DBIC::Schema/;

use Zonestat;

my ($connect, $user, $pwd) = Zonestat->new->dbconfig;

__PACKAGE__->config(
    schema_class => 'Zonestat::DBI',
    connect_info => [$connect, $user, $pwd, {AutoCommit => 1, RaiseError => 1, PrintError => 0}],
);


=head1 NAME

Statweb::Model::DB - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
