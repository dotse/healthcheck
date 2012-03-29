package Zonestat::Gather;

use 5.008008;
use strict;
use utf8;
use warnings;

use base 'Zonestat::Common';

use Carp;
use Try::Tiny;
use Net::LibIDN ':all';
use IO::Handle;

our $VERSION = '0.02';
our $debug   = 0;
## no critic (Modules::RequireExplicitInclusion)
# Seriously, Critic?
STDOUT->autoflush( 1 ) if $debug;
## use critic

sub enqueue_domainset {
    die "Unimplemented.";
}

sub single_domain {
    my $self   = shift;
    my $domain = shift;
    my $extra  = shift;
    my $id;

    my $db = $self->db( 'zonestat' );
    my $data = $self->parent->collect->for_domain( idn_to_ascii( $domain, 'UTF-8' ) );
    $data->{domain} = $domain;
    while ( my ( $k, $v ) = each %$extra ) {
        $data->{$k} = $v unless exists( $data->{$k} );
    }

    if ( $extra->{testrun} ) {
        my $nsdb = $self->db( 'zonestat-nameserver' );
        foreach my $geo ( @{ $data->{geoip} } ) {
            if ( $geo->{type} eq 'nameserver' ) {
                my $nsid = $extra->{testrun} . '-' . $geo->{address};
                try {
                    $nsdb->newDoc(
                        $nsid, undef,
                        {
                            testrun   => $extra->{testrun},
                            address   => $geo->{address},
                            ipversion => $geo->{ipversion},
                        }
                    )->create;
                }
                catch {
                    unless ( /^Storage error: 409 Conflict/ ) {
                        die( $_ );    # If it's not a conflict, rethrow
                    }
                };
            }
        }

        $id = $extra->{testrun} . '-' . $domain;
    }

    my $res;
    if ( $db->docExists( $id ) ) {
        $res = $db->newDoc( $id )->retrieve;
        $res->data( $data );
        $res->update;
    }
    else {
        $res = $db->newDoc( $id, undef, $data )->create;
    }

    return $res;
}

sub put_in_queue {
    my ( $self, @qrefs ) = @_;
    my $db = $self->db( 'zonestat-queue' );
    my @tmp;

    foreach my $ref ( @qrefs ) {
        unless ($ref->{domain}
            and defined( $ref->{priority} )
            and $ref->{priority} > 0 )
        {
            carp "Invalid domain and/or priority: " . $ref->{domain} . '/' . $ref->{priority};
            return;
        }

        push @tmp, $db->newDoc( undef, undef, $ref );
    }

    return $db->bulkStore( \@tmp );

}

sub get_from_queue {
    my $self = shift;
    my $limit = shift || 10;
    my @res;
    my $db   = $self->db( 'zonestat-queue' );
    my $ddoc = $db->newDesignDoc( '_design/queues' );
    $ddoc->retrieve;

    my $query;

    do {
        try {
            $query = $ddoc->queryView( 'fetch', limit => $limit );
        }
        catch {    # Failed to get something from the queue. Sleep a bit and try again.
            sleep( 2 );
        };
    } until ( defined($query) );
    foreach my $d ( @{ $query->{rows} } ) {
        my $doc = $db->newDoc( $d->{id}, undef, $d );
        $doc->retrieve;
        $doc->data->{inprogress} = 1;
        try {
            $doc->update;
            my $tmp = $doc->data;
            $tmp->{id} = $doc->id;
            push @res, $tmp;
        }
        catch {
            print STDERR "Failed to update: " . $doc->data->{domain} . "\n"
              if $debug;
        };
    }

    return @res;
}

sub set_active {
    my ( $self, $id, $pid ) = @_;
    my $db  = $self->db( 'zonestat-queue' );
    my $doc = $db->newDoc( $id );
    $doc->retrieve;

    $doc->data->{tester_pid} = $pid;
    $doc->update;

    return $doc;
}

sub reset_queue_entry {
    my $self = shift;
    my $id   = shift;
    my $doc  = $self->db( 'zonestat-queue' )->newDoc( $id );

    $doc->retrieve;
    $doc->data->{inprogress} = undef;
    $doc->data->{tester_pid} = undef;
    $doc->update;

    return $doc;
}

sub reset_inprogress {
    my $self = shift;
    my $db   = $self->db( 'zonestat-queue' );
    my $ddoc = $db->newDesignDoc( '_design/queues' );
    $ddoc->retrieve;
    my $query = $ddoc->queryView( 'inprogress' );
    foreach my $row ( @{ $query->{rows} } ) {
        my $doc = $db->newDoc( $row->{id} );
        $doc->retrieve;
        $doc->data->{inprogress} = undef;
        $doc->update;
    }

    return;
}

sub requeue {
    my $self = shift;
    my $id   = shift;
    my $doc  = $self->db( 'zonestat-queue' )->newDoc( $id );
    my $count;
    my $continue = 1;
    my $delay    = 1;

    while ( $continue ) {
        try {
            $doc->retrieve;
            $continue = undef;
        }
        catch {
            $count++;
            if ( $count > 5 ) {
                die "Failed to requeue $id";
            }
            sleep $delay;
            $delay *= 2;
        };
    }
    $doc->data->{priority} += 1;
    $doc->data->{requeued} += 1;
    $doc->data->{inprogress} = undef;
    if ( $doc->data->{requeued} <= 5 ) {
        $delay    = 1;
        $count    = 0;
        $continue = 1;
        while ( $continue ) {
            try {
                $doc->update;
                $continue = undef;
            }
            catch {
                $count++;
                if ( $count > 5 ) {
                    die "Failed to requeue $id";
                }
                sleep $delay;
                $delay *= 2;
            };
        }
        return 1;
    }
    else {
        if ( $doc->data->{source_data} ) {
            my $newdoc = $self->db( 'zonestat' )->newDoc( $doc->data->{source_data} . '-' . $doc->data->{domain} );
            $newdoc->data->{failed}  = 1;
            $newdoc->data->{domain}  = $doc->data->{domain};
            $newdoc->data->{testrun} = 0 + $doc->data->{source_data};
            $newdoc->create;
            $doc->delete;
        }
        return;
    }
}

1;
__END__

=head1 NAME

Zonestat::Gather - gather and store statistics

=head1 SYNOPSIS

  use Zonestat;
  
  my $gather = Zonestat->new->gather;

=head1 DESCRIPTION

=head2 Methods

=over 4

=item single_domain($domainname, [$href])

Takes a domain name and optionally a reference to a hash with extra
information. It runs a data collection for the domain, then stores the
resulting information in the configured CouchDB instance.

The extra information hash is mostly used by the dispatcher daemon to store
which testrun the collection was done for.

=item put_in_queue(@qlist)

Takes a list of references to hashes, and uses them to add domains to the
queue database. The hashes must have two keys, C<domain> and C<priority>. The
first should be a domain name, and the second a positive integer value.

=item get_from_queue([$limit])

Retrieves a number of documents from the queue database. Optionally takes one
argument, the maximum number of entries to return. If no limit is specified,
it defaults to ten. The returned documents will have been marked as "in
progress" in the queue database.

=item set_active($id, $pid)

Set the queue item with ID C<$id> as active and being gathered by process number C<$pid>.

=item reset_queue_entry($id)

Mark the specified queue entry as not being processed.

=item reset_inprogress()

If any queue entries are currently marked as being in progress, unmark them.
Used by the dispatcher at startup, in case there is stale information left
over after a crash.

=item requeue($id)

Requeue the specified queue entry. Normally, this is done by the dispatcher
after a gathering child fails to exit gracefully. The entry will be returned
to the queue at a lower priority (that is, with a numerically larger priority
number), so it will be tried again at the end of the queue. If an item is
requeued more than five times, it will be marked as failed and removed from
the queue.

=back

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
