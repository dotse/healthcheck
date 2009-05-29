package Zonestat::Config;

use 5.008008;
use strict;
use warnings;

use YAML qw[Load LoadFile];

our $VERSION = '0.01';

our $defaults = Load(join('', <DATA>));

sub new {
    my $class = shift;
    my $overrides;

    if (@_ == 1) {
        $overrides = LoadFile($_[0]);
    } else {
        $overrides = {@_};
    }

    my $self = {};
    bless $self, $class;

    $self->deepcopy($self, $defaults);
    $self->deepcopy($self, $overrides);

    return $self;
}

sub get {
    my $self = shift;
    my @keys = @_;

    while (@keys) {
        my $k = shift @keys;
        $self = $self->{$k};
    }

    return $self;
}

sub set {
    my $self = shift;
    my $val  = shift;
    my @keys = @_;

    while (@keys > 1) {
        my $k = shift @keys;
        $self = $self->{$k};
    }

    $self->{ $keys[0] } = $val;
}

# Helper methods

sub deepcopy {
    my $self = shift;
    my ($target, $source) = @_;

    while (my ($k, $v) = each %$source) {
        if (!ref($v) or ref($v) ne 'HASH') {
            $target->{$k} = $v;
        } elsif (!defined($target->{$k})
            or !ref($target->{$k})
            or ref($target->{$k}) ne 'HASH')
        {
            $target->{$k} = {};
            $self->deepcopy($target->{$k}, $v);
        } else {
            $self->deepcopy($target->{$k}, $v);
        }
    }
}

1;

=head1 NAME

Zonestat::Config - handle configuration tasks for Zonestat modules

=head1 SYNOPSIS

  use Zonestat::Config;

=head1 DESCRIPTION

=over

=item ->new([filename | opthash])

The C<new()> method creates a config object. It will read a default
configuration from data included with the module, and override those defaults
with data specified in the call, if any. The specification can be done by
either providing a single filename argument, or an even number of arguments in
C<key =<gt> value> form. If it is a file name, the specified file will be read
and parsed as YAML.

=item ->get(@keylist)

Given a list of keys descending down through the configuration structure, this
method will return the stored value.

=item ->set($value, @keylist)

Given a value and a list of keys descending through the configuration
structure, this method will set the value for the given key to the given
value.

=back

=head1 EXAMPLES

  my $conf = Zonestat::Config->new(dbi => {password => 'gazonk'});
  print $conf->get('dbi','host');
  $conf->set('zonestat', qw[dbi username]);

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

__DATA__

dbi:
    host: 127.0.0.1
    port: 3306
    database: dnscheck
    user: dnscheck
    password: dnscheck

zone:
    name: se.
    servers:
        - philby.nic.se
        - burgess.nic.se
    flagdomains:
        - aaanicsecontrolzoneadfasldkjfansjjhjlhd.se
        - dddnicsecontrolzonedfalksdjflkasdlkfjad.se
        - gggnicsecontrolzonehalskjdfhakjlsdfaskd.se
        - kkknicsecontrolzonentvsadfksajdshfajsdd.se
        - nnnnicsecontrolzoneahsdqibwbercvhufasbd.se
        - ooonicsecontrolzoneefuqasdfajewkfdgyyfd.se
        - qqqnicsecontrolzonegqfyegfudoqwegfhjdsa.se
        - tttnicsecontrolzonefqwgeufyqewyefygasdf.se
        - vvvnicsecontrolzoneqwrfiuqhurwhdfuasads.se
        - xxxnicsecontrolzoneqifilqwiehefqwdfasda.se
    datafile: /var/tmp/se.zone
    tsig: dummy

programs:
    dig: /usr/bin/dig

