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

1;