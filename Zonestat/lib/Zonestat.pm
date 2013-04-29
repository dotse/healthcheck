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
use Zonestat::DB::Asdata;

our $VERSION = '0.04';

## no critic (Subroutines::RequireArgUnpacking)
sub new {
    my $class = shift;
    my $self = bless {}, $class;

    unless ( @_ and $_[0] ) {
        @_ = ( $Config{siteprefix} . '/share/zonestat/config' );
    }

    $self->{conf}    = Zonestat::Config->new( @_ );
    $self->{prepare} = Zonestat::Prepare->new( $self );
    $self->{gather}  = Zonestat::Gather->new( $self );
    $self->{present} = Zonestat::Present->new( $self );
    $self->{collect} = Zonestat::Collect->new( $self );
    
    if ($self->cget(qw[couchdb dbprefix])) {
        $self->{dbprefix} = $self->cget(qw[couchdb dbprefix])
    }

    return $self;
}
## use critic

## no critic (Subroutines::RequireArgUnpacking)
sub cget {
    my $self = shift;

    return $self->{conf}->get( @_ );
}
## use critic

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

    return Zonestat::DB::Domainset->new( $self, $name );
}

sub testrun {
    my $self = shift;
    my $id   = shift;

    return Zonestat::DB::Testrun->new( $self, $id );
}

sub queue {
    my $self = shift;
    return Zonestat::DB::Queue->new( $self );
}

sub dbproxy {
    my $self = shift;
    my $name = shift;
    
    if ($self->{dbprefix}) {
        $name =~ s/zonestat/$self->{dbprefix}/e;
    }

    return Zonestat::DB->new( $self, $name );
}

sub user {
    my ( $self, $name_or_id, $pwd ) = @_;

    return Zonestat::DB::User->new( $self );
}

sub asdata {
    my $self = shift;
    return Zonestat::DB::Asdata->new( $self );
}

sub dbconfig {
    my $self = shift;

    my $c = $self->{conf}->get( 'couchdb' );

    if (!$c) { # If we can't find a config, default to localhost
        return {url => 'http://127.0.0.1:5984/'};
    }

    return $c;
}

sub dbconn {
    my $self = shift;

    unless ( $self->{dbconn} and $self->{dbconn}->testConnection ) {
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

    if ($self->{dbprefix}) {
        $name =~ s/zonestat/$self->{dbprefix}/e;
    }

    unless ( $self->{db}{$name} ) {
        my $db = $self->dbconn->newDB( $name );
        unless ( $self->dbconn->dbExists( $name ) ) {
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
  my $zs = Zonestat->new;

=head1 DESCRIPTION

This module is the main entry point for the Zonestat system.

=head2 Methods

=over

=item new([$configfile])

Create a new C<Zonestat> object. Takes one optional argument, the suffix-less
path to the configfile to use.

=item cget(@names)

Retrieve config information. The arguments are a list of descending keys into
the nested config hash. So, for example, to get the URL to the CouchDB
instance we should use, we call C<$zs->cget('couchdb','url')>.

=item collect()

Return a properly set up instance of Zonestat::Collect.

=item prepare()

Return a properly set up instance of Zonestat::Prepare.

=item gather()

Return a properly set up instance of Zonestat::Gather.

=item present()

Return a properly set up instance of Zonestat::Present.

=item domainset([$name])

Return a properly set up instance of Zonestat::DB::Domainset. If an argument is
given, it must be the name of a domainset. An object for that domainset will
then be returned.

=item testrun()

Return a properly set up instance of Zonestat::DB::Testrun. If an argument is
given, it must be the id number of a testrun. An object for that testrun will
then be returned.

=item queue()

Return a properly set up instance of Zonestat::DB::Queue.

=item dbproxy($name)

Takes the name of a database in the configured CouchDB instance, and returns a
Zonestat::DB object for it.

=item user()

Return a properly set up instance of Zonestat::DB::User.

=item asdata()

Return a properly set up instance of Zonestat::DB::Asdata.

=item dbconfig

Returns the same thing as C<$Zonestat->new->cget('couchdb')>.

=item dbconn

Returns a L<CouchDB::Client> object with a working connection to the
configured CouchDB instance.

=item db($name)

Returns a L<CouchDB::Client::DB> object for the specified database in the
configured CouchDB instance.

=back

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
