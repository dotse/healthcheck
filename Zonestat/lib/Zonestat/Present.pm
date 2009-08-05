package Zonestat::Present;

use 5.008008;
use strict;
use warnings;

use base 'Zonestat::Common';

our $VERSION = '0.01';

sub total_tested_domains {
    my $self = shift;
    my $ds   = shift;

    if (defined($ds)) {
        $ds = $ds->tests;
    } else {
        $ds = $self->dbx('Tests');
    }

    return $ds->search(
        {},
        {
            columns  => ['domain'],
            distinct => 1
        }
    )->count;
}

sub lame_delegated_domains {
    my $self = shift;
    my ($ds) = @_;

    if (defined($ds)) {
        $ds = $ds->tests->search_related('results', {});
    } else {
        $ds = $self->dbx('Results');
    }
    return $ds->search(
        { 'message' => 'NAMESERVER:NOT_AUTH' },
        { 'columns' => [qw(test_id)], 'distinct' => 1 }
    )->count;
}

sub number_of_domains_with_message {
    my $self  = shift;
    my $level = shift || 'ERROR';
    my $ds    = shift;

    if (defined($ds)) {
        $ds = $ds->tests->search_related('results', {});
    } else {
        $ds = $self->dbx('Results');
    }

    return map { [$_->message, $_->get_column('count')] } $ds->search(
        { level => $level },
        {
            select   => ['message', { count => '*' }],
            as       => [qw/message count/],
            group_by => ['message'],
            order_by => ['count(*) DESC']
        }
    )->all;
}

sub number_of_servers_with_software {
    my $self = shift;
    my ($https, $ds) = @_;

    my $s;

    if (defined($ds)) {
        $s =
          $ds->glue->search_related('domain', {})
          ->search_related('webservers',      {});
    } else {
        $s = $self->dbx('Webserver');
    }

    return map { [$_->type, $_->get_column('count')] } $s->search(
        { https => ($https ? 1 : 0) },
        {
            select   => ['type', { count => '*' }],
            as       => ['type', 'count'],
            group_by => ['type'],
            order_by => ['count(*) DESC'],
        }
    )->all;
}

sub unknown_server_strings {
    my $self = shift;
    my $ds   = shift;

    if (defined($ds)) {
        $ds =
          $ds->glue->search_related('domain', {})
          ->search_related('webservers',      {});
    } else {
        $ds = $self->dbx('Webserver');
    }

    return map { $_->raw } $ds->search({ type => 'Unknown' },
        { columns => ['raw'], distinct => 1, order_by => ['raw'] })->all;
}

sub all_dnscheck_tests {
    my $self = shift;
    my $ds   = shift;

    my $s;

    if (defined($ds)) {
        $s = $ds->tests;
    } else {
        $s = $self->dbx('Tests');
    }

    return $s->search({}, { order_by => ['domain'] });
}

sub all_domainsets {
    my $self = shift;

    my $s = $self->dbx('Domainset');
    return $s->search({}, { order_by => ['name'] });
}

sub tests_with_max_severity {
    my $self = shift;
    my $ds = shift;
    
    my $tests;
    if (defined($ds)) {
        $tests = $ds->tests;
    } else {
        $tests = $self->dbx('Tests')->search({})
    }

    my %res;
    
    foreach my $t ($tests->all) {
        if ($t->count_critical > 0) {
            $res{critical}++
        } elsif ($t->count_error > 0) {
            $res{error}++
        } elsif ($t->count_warning > 0) {
            $res{warning}++
        } elsif ($t->count_notice > 0) {
            $res{notice}++
        } elsif ($t->count_info > 0) {
            $res{info}++
        } else {
            $res{clear}++
        }
    }
    
    return (
        [critical => $res{critical}],
        [error => $res{error}],
        [warning => $res{warning}],
        [notice => $res{notice}],
        [info => $res{info}],
        [clear => $res{clear}]
    );
}

1;
__END__

=head1 NAME

Zonestat::Present - present gathered statistics

=head1 SYNOPSIS

  use Zonestat::Present;

=head1 DESCRIPTION


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
