package Zonestat::Gather;

use 5.008008;
use strict;
use warnings;

use base 'Zonestat::Common';

use Carp;
use Try::Tiny;

our $VERSION = '0.02';
our $debug   = 0;
STDOUT->autoflush(1) if $debug;

sub enqueue_domainset {
    my $self     = shift;
    my $set_name = shift;

    die "Unimplemented.";
}

sub single_domain {
    my $self   = shift;
    my $domain = shift;
    my $extra  = shift;
    my $id;

    my $db   = $self->db('zonestat');
    my $data = $self->parent->collect->for_domain($domain);
    $data->{domain} = $domain;
    while (my ($k, $v) = each %$extra) {
        $data->{$k} = $v unless exists($data->{$k});
    }

    if ($extra->{testrun}) {
        $id = $extra->{testrun} . '-' . $domain;
    }

    return $db->newDoc($id, undef, $data)->create;
}

sub put_in_queue {
    my $self    = shift;
    my (@qrefs) = @_;
    my $db      = $self->db('zonestat-queue');

    foreach my $ref (@qrefs) {
        unless ($ref->{domain}
            and defined($ref->{priority})
            and $ref->{priority} > 0)
        {
            carp "Invalid domain and/or priority: "
              . $ref->{domain} . '/'
              . $ref->{priority};
            return;
        }

        $db->newDoc(undef, undef, $ref)->create;
    }
}

sub get_from_queue {
    my $self = shift;
    my $limit = shift || 10;
    my @res;
    my $db   = $self->db('zonestat-queue');
    my $ddoc = $db->newDesignDoc('_design/queues');
    $ddoc->retrieve;

    my $query = $ddoc->queryView('fetch', limit => $limit);
    foreach my $d (@{ $query->{rows} }) {
        my $doc = $db->newDoc($d->{id}, undef, $d);
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
    my $self = shift;
    my ($id, $pid) = @_;
    my $db  = $self->db('zonestat-queue');
    my $doc = $db->newDoc($id);
    $doc->retrieve;

    $doc->data->{tester_pid} = $pid;
    $doc->update;

    return $doc;
}

sub reset_queue_entry {
    my $self = shift;
    my $id   = shift;
    my $doc  = $self->db('zonestat-queue')->newDoc($id);

    $doc->retrieve;
    $doc->data->{inprogress} = undef;
    $doc->data->{tester_pid} = undef;
    $doc->update;

    return $doc;
}

sub reset_inprogress {
    my $self = shift;
    my $db   = $self->db('zonestat-queue');
    my $ddoc = $db->newDesignDoc('_design/queues');
    $ddoc->retrieve;
    my $query = $ddoc->queryView('inprogress');
    foreach my $row (@{ $query->{rows} }) {
        my $doc = $db->newDoc($row->{id});
        $doc->retrieve;
        $doc->data->{inprogress} = undef;
        $doc->update;
    }
}

sub requeue {
    my $self = shift;
    my $id   = shift;
    my $doc  = $self->db('zonestat-queue')->newDoc($id);

    $doc->retrieve;
    $doc->data->{priority} += 1;
    $doc->data->{requeued} += 1;
    $doc->data->{inprogress} = undef;
    if ($doc->data->{requeued} <= 5) {
        $doc->update;
        return 1;
    } else {
        $doc->delete;
        if ($doc->data->{source_data}) {
            my $newdoc =
              $self->db('zonestat')
              ->newDoc($doc->data->{source_data} . '-' . $doc->data->{domain});
            $newdoc->data->{failed}  = 1;
            $newdoc->data->{domain}  = $doc->data->{domain};
            $newdoc->data->{testrun} = $doc->data->{source_data};
            $newdoc->create;
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

=item ->enqueue_domainset($domainset, [$name])

Put all domains in the given domainset object on the gathering queue and
create a new testrun object for it. If a second argument is given, it will be
used as the name of the testrun. If no name is given, a name based on the
current time will be generated.

=item ->get_server_data($trid, $domainname)

Given the ID number of a testrun object and the name of a domain, gather all
data for that domain and store in the database associated with the given
testrun.

=item ->rescan_unknown_servers()

Walk through the list of all Webserver objects with type 'Unknown' and reapply
the list of server type regexps. To be used when the list of regexps has been
extended.

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
