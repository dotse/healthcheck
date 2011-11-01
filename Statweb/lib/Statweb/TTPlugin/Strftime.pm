package Statweb::TTPlugin::Strftime;

use Template::Plugin::Filter;
use base 'Template::Plugin::Filter';
use POSIX 'strftime';

sub init {
    my $self = shift;
    
    $self->install_filter('strftime');
}

sub filter {
    my ($self, $content) = @_;
    
    return strftime('%F %T', localtime($content));
}

=head1 NAME

Statweb::TTPlugin::Strftime -- time-formatting plugin for Template Toolkit

=head1 DESCRIPTION

A filter plugin for Template::Toolkit that takes a C<time_t> value and formats
it to an ISO8601-format human-readable string.

=head1 SEE ALSO

L<Template::Toolkit>

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;