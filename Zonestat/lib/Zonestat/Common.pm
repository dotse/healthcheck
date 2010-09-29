package Zonestat::Common;

use 5.008008;
use strict;
use warnings;

use Try::Tiny;

our $VERSION = '0.02';
my $source_id_string  = q[Zonestat];
my $source_id_contact = q[calle@init.se];
my $run_id;

sub new {
    my $class = shift;
    return bless { parent => shift }, $class;
}

sub parent {
    my $self = shift;

    return $self->{parent};
}

sub cget {
    my $self = shift;

    return $self->{parent}->cget(@_);
}

sub db {
    my $self = shift;

    return $self->parent->db(@_);
}

sub run_id {
    my $self = shift;
    my $docid = 'testruncounter';
    my $db = $self->db('zonestat_misc');
    
    if (!defined($run_id)) {
        my $doc = $db->newDoc($docid);
        unless($db->docExists($docid)) {
            $db->newDoc($docid, undef, {counter => 0})->create;
        }
        
        my $i = 0;
        while (!defined($run_id) and ++$i <= 10) {
            try {
                $doc->retrieve;
                $doc->data->{counter} = $doc->data->{counter} + 1;
                $doc->update;
                $run_id = $doc->data->{counter};
            }
        }
        
        croak "Failed to get new testrun id" unless defined($run_id);
    }

    return $run_id;
}

1;
__END__

=head1 NAME

Zonestat::Common - parent module for the worker modules.

=head1 SYNOPSIS

  use base 'Zonestat::Common';

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
