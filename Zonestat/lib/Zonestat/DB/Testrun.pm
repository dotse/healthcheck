package Zonestat::DB::Testrun;

use strict;
use utf8;
use warnings;

use base 'Zonestat::DB::Common';

use POSIX qw[strftime];

sub fetch {
    my $self = shift;

    my $doc = $self->db( 'zonestat-testrun' )->newDoc( $self->{id} );
    $doc->retrieve;

    $self->{doc} = $doc;

    return $self;
}

sub tests {
    my ($self, $startdomain, $reverse, $count) = @_;
    $startdomain ||= '';
    $count ||= 26;
    
    my $res = $self->dbproxy('zonestat')
        ->test_run(
            startkey => [0+$self->id, $startdomain],
            include_docs => 'true',
            limit => $count,
            descending => $reverse,
        );
    
    return [grep {$_->{testrun} == $self->id} map {$_->{doc}} @{$res->{rows}}];
}

sub domainset {
    my $self = shift;

    return $self->data->{domainset};
}

sub name {
    my $self   = shift;
    my $dset   = $self->domainset;
    my $time_t = $self->data->{queued_at};

    return $dset . ' ' . strftime( '%Y-%m-%d %H:%M', localtime( $time_t ) );
}

sub test_count {
    my $self = shift;

    my $dbp = $self->dbproxy( 'zonestat' );
    my $res = $dbp->test_count( group => 1, key => $self->data->{testrun} );

    if ( $res->{rows}[0] ) {
        return $res->{rows}[0]{value};
    }
    else {
        return 0;
    }
}

=head1 NAME

Zonestat::DB::Testrun - database interface class for testruns

=head1 SYNOPSIS

my $tr = Zonestat->new->testrun(17);

=head1 DESCRIPTION

=head2 Methods

=over

=item tests($startdomain, $reverse, $count)

Fetch data objects for a sequential number of domains in this run.
C<$startdomain> is where to start, C<$reverse> is a true/false flag indicating
the sorting direction and C<$count> is the maximum number od documents to
return.

=item domainset()

The C<Zonestat::DB::Domainset> object this run belongs to.

=item name()

The name of this run, generated from the name of the domainset it belongs to
and the time the run was put into the gathering queue.

=item test_count()

The number of gathered domains in this run.

=back

1;
