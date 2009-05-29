package Zonestat::Common;

use 5.008008;
use strict;
use warnings;

use DBI;

our $VERSION = '0.01';

sub new {
    my $class = shift;
    return bless { parent => shift }, $class;
}

sub cget {
    my $self = shift;

    return $self->{parent}->cget(@_);
}

sub dbh {
    my $self = shift;
    my $c    = $self->cget('dbi');

    return $self->{dbh} if (defined($self->{dbh}) and $self->{dbh}->ping);

    my $dsn = sprintf("DBI:mysql:database=%s;hostname=%s;port=%s",
        $c->{"database"}, $c->{"host"}, $c->{"port"});
    my $dbh =
      DBI->connect($dsn, $c->{user}, $c->{password},
        { AutoRaise => 1, AutoCommit => 1 });
    die "Failed to connect to database: " . $DBI::errstr . "\n"
      unless defined($dbh);
    $self->{dbh} = $dbh;
    return $dbh;
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
