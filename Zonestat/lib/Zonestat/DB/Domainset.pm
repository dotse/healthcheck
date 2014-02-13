package Zonestat::DB::Domainset;

use strict;
use utf8;
use warnings;

use base 'Zonestat::DB::Common';

use Digest;
use Try::Tiny;

sub sha1_hex {
    my ($string) = @_;

    return Digest->new("SHA1")->add($string)->hexdigest;
}

sub all_sets {
    my $self = shift;
    my $dbp  = $self->dbproxy( 'zonestat-dset' );

    ## no critic (Modules::RequireExplicitInclusion)
    return map { __PACKAGE__->new( $self->parent, $_ ) } map { $_->{key} } @{ $dbp->util_set( group => 1 )->{rows} };
}

sub new {
    my $class  = shift;
    my $parent = shift;
    my $self   = $class->SUPER::new( $parent );
    $self->{name} = shift;

    return $self;
}

sub name {
    my $self = shift;

    return ( $self->{name} || '' );
}

sub db {
    my $self = shift;
    my $name = shift || 'zonestat-dset';

    return $self->SUPER::db( $name );
}

sub dbproxy {
    my $self = shift;
    my $name = shift || 'zonestat-dset';

    return $self->SUPER::dbproxy( $name );
}

sub id {
    my $self   = shift;
    my $domain = shift;

    return ( $self->name . '-' . ( $domain || '' ) );
}

sub add {
    my ( $self, @domains ) = @_;
    my $name = $self->name;

    $self->db->bulkStore( [ map { $self->db->newDoc( $self->id( $_ ), undef, { domain => $_, set => $name } ) } @domains ] );

    return $self;
}

sub remove {
    my $self   = shift;
    my $domain = shift;

    my $doc = $self->db->newDoc( $self->id( $domain ), undef );
    try {
        $doc->retrieve;
        $doc->delete;
    };

    return $self;
}

sub all {
    my $self = shift;
    my $ddoc = $self->dbproxy;

    return [ map { $_->{value} } @{ $ddoc->util_set( key => $self->name, reduce => 'false' )->{rows} } ];
}

sub all_docs {
    my $self = shift;
    my $ddoc = $self->dbproxy;

    return [ map { $_->{doc} } @{ $ddoc->util_set( key => $self->name, reduce => 'false', include_docs => 'true' )->{rows} } ];
}

sub clear {
    my $self = shift;

    foreach my $domain ( @{ $self->all } ) {
        my $doc = $self->db->newDoc( $self->id( $domain ) );
        try {
            $doc->retrieve;
            $doc->delete;
        }
        catch {
            print 'Failure: ' . $_ . "\n";
        }
    }

    return $self;
}

sub testruns {
    my $self = shift;

    my $dbp = $self->dbproxy( 'zonestat-testrun' );
    my $res = $dbp->info_dsets( reduce => 'false', key => $self->name );

    return sort {$b->id <=> $a->id} map { $self->parent->testrun( $_ ) } map { $_->{id} } @{ $res->{rows} };
}

sub enqueue {
    my $self    = shift;
    my $testrun = $self->run_id;

    my $trdoc = $self->db( 'zonestat-testrun' )->newDoc(
        $testrun, undef,
        {
            domainset => $self->name,
            queued_at => time(),
            testrun   => $testrun
        }
    );
    $trdoc->create;

    $self->parent->gather->put_in_queue( map { { domain => $_, priority => 5, source_data => $testrun, } } @{ $self->all } );

    return $testrun;
}

sub page {
    my ( $self, $page, $rows ) = @_;

    $rows ||= 26;
    my $dbp = $self->dbproxy( 'zonestat-dset' );

    my $res = $dbp->util_page( startkey => [ $self->name, $page ], limit => $rows );
    my @rows = map { $_->{key}[1] } grep { $_->{key}[0] eq $self->name } @{ $res->{rows} };
    my $next;

    if ( $rows == scalar( @rows ) ) {
        $next = $rows[-1];
        @rows = @rows[ 0 .. $#rows - 1 ];
    }

    return ( \@rows, $next );
}

sub prevkey {
    my ( $self, $page, $rows ) = @_;

    $rows ||= 26;
    my $dbp = $self->dbproxy( 'zonestat-dset' );

    my $res = $dbp->util_page( startkey => [ $self->name, $page ], limit => $rows, descending => 1 );
    my @rows = map { $_->{key}[1] } grep { $_->{key}[0] eq $self->name } @{ $res->{rows} };

    return $rows[-1];
}

1;

=head1 NAME

Zonestat::DB::Domainset - database interface class for domainsets

=head1 SYNOPSIS

my $ds = Zonestat->new->domainset($name);

=head1 DESCRIPTION

=head2 Class Methods

=over

=item all_sets()

Returns a list with the names of all domainsets currently in the database.

=back

=head2 Instance Methods

=over

=item name()

Returns the name of the domainset.

=item db()

Returns a L<CouchDB::Client::DB> object for the C<zonestat-dset> database.

=item dbproxy

Returns a Zonestat database proxy object for C<zonestat-dset>.

=item id($domainname)

Returns the ID for a domain in this set. Yes, it's a badly named method.

=item add(@domainnames)

Takes a list of domain names and adds them to the set. If a name is already in
the set, it will be silently ignored.

=item remove($domainname)

Takes a single domain name and removes it from the set, if it's there.

=item all()

Returns a list with all the domain names in this set.

=item all_docs()

Returns a list of all the full data hashes for the domains in this set.

=item clear()

Remove all domains from the set.

=item testruns()

Returns a list with all the L<Zonestat::DB::Testrun> objects relatede to this domainset.

=item enqueue()

Put all the domains in this set on the gathering queue.

=item page($start, [$rows])

Utility method. Returns a two-element list. The first is a list of domain
names in this set, starting with the one given in C<$start>. There will be a
maximum of C<$rows> (defaulting to 25). The second element is the proper
domain name to use as C<$start> to get the following batch of names.

=item prevkey($start, [$rows])

Takes the same arguments as L<page()>, but the returns only the proper domain
name to use as the C<$start> argument in order to get the preceeding batch of names.

=back
