package Statweb::Model::DB;

use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

use Zonestat;
use Data::Dumper;

has 'zs' => (
    is => 'ro',
    isa => 'Zonestat',
    lazy_build => 1,
    handles => {
        db => 'db',
        present => 'present',
        gather => 'gather',
        dset => 'domainset',
        user => 'user',
        testrun => 'testrun',
        queue => 'queue',
        asdata => 'asdata',
        domainset => 'domainset',
    },
);

sub _build_zs {
    return Zonestat->new;
}


=head1 NAME

Statweb::Model::DB -- Catalyst model class that interfaces to L<Zonestat>

=head1 DESCRIPTION

There is a main method, C<zs()>, that returns a L<Zonestat> object. There are
also a number of convenience methods that simply delegate to the object
returned by C<zs()>. They are:

=over

=item db()

=item present()

=item gather()

=item dset()

Delegates to L<Zonestat::domainset()>.

=item user()

=item testrun()

=item queue()

=item asdata()

=item domainset()

=back

For information about the various methods, see the L<Zonestat> documentation.

=head1 SEE ALSO

L<Statweb>

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;