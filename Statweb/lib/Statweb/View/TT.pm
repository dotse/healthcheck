package Statweb::View::TT;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    WRAPPER            => 'wrapper.tt',
    TIMER              => 1,
    EVAL_PERL          => 1,
);

=head1 NAME

Statweb::View::TT - TT View for Statweb

=head1 DESCRIPTION

TT View for Statweb.

=head1 SEE ALSO

L<Statweb>

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
