package Zonestat;

use 5.008008;
use strict;
use warnings;
use utf8;

use Config;
use CouchDB::Client;
use Carp;

use Zonestat::Config;
use Zonestat::Common;
use Zonestat::Prepare;
use Zonestat::Gather;
use Zonestat::Present;
use Zonestat::DB::User;
use Zonestat::Collect;
use Zonestat::DB::Domainset;
use Zonestat::DB::Testrun;
use Zonestat::DB;
use Zonestat::DB::Queue;

use Module::Find;

our $VERSION = '0.03';

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    unless (@_) {
        @_ = ($Config{siteprefix} . '/share/dnscheck/site_config.yaml');
    }

    $self->{conf}    = Zonestat::Config->new(@_);
    $self->{prepare} = Zonestat::Prepare->new($self);
    $self->{gather}  = Zonestat::Gather->new($self);
    $self->{present} = Zonestat::Present->new($self);
    $self->{collect} = Zonestat::Collect->new($self);

    $self->register_plugins;

    return $self;
}

sub plugins {
    my $self = shift;

    return @{ $self->{plugins} };
}

sub register_plugins {
    my $self = shift;

    my @plugins = useall ZonestatPlugin;
    $self->{plugins} = [@plugins];

    foreach my $mod (@plugins) {

        # Do something useful here
    }

    return;
}

sub cget {
    my $self = shift;

    return $self->{conf}->get(@_);
}

sub collect {
    my $self = shift;
    return $self->{collect};
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

sub domainset {
    my $self = shift;
    my $name = shift;

    return Zonestat::DB::Domainset->new($self, $name);
}

sub testrun {
    my $self = shift;
    my $id   = shift;

    return Zonestat::DB::Testrun->new($self, $id);
}

sub queue {
    my $self = shift;
    return Zonestat::DB::Queue->new($self);
}

sub dbproxy {
    my $self = shift;
    my $name = shift;

    return Zonestat::DB->new($self, $name);
}

sub user {
    my $self = shift;
    my ($name_or_id, $pwd) = @_;

    return Zonestat::DB::User->new($self);
}

sub dbconfig {
    my $self = shift;

    return $self->{conf}->get('couchdb');
}

sub dbconn {
    my $self = shift;

    unless ($self->{dbconn} and $self->{dbconn}->testConnection) {
        my $conn = CouchDB::Client->new(
            uri      => $self->dbconfig->{url},
            username => $self->dbconfig->{username},
            password => $self->dbconfig->{password},
        );
        $conn->testConnection or croak "Failed to get connection to database.";
        $self->{dbconn} = $conn;
    }

    return $self->{dbconn};
}

sub db {
    my $self = shift;
    my $name = shift;

    confess "Database must have a name" unless $name;

    unless ($self->{db}{$name}) {
        my $db = $self->dbconn->newDB($name);
        unless ($self->dbconn->dbExists($name)) {
            $db->create;
        }
        $self->{db}{$name} = $db;
    }

    return $self->{db}{$name};
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
