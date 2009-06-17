package Zonestat::Prepare;

use 5.008008;
use strict;
use warnings;

use base 'Zonestat::Common';

our $VERSION = '0.01';

sub all {
    my $self = shift;

    if ($self->fetch_zone) {
        $self->db_import_zone;
    }
}

sub fetch_zone {
    my $self = shift;

    my $dig  = $self->cget(qw[programs dig]);
    my $zcfg = $self->cget('zone');

    foreach my $server (@{ $zcfg->{servers} }) {
        my $cmd = sprintf("%s -y %s axfr %s @%s > %s",
            $dig, $zcfg->{tsig}, $zcfg->{name}, $server, $zcfg->{datafile});
        system $cmd;
        open my $zfile, '<', $zcfg->{datafile}
          or die "Failed to open " . $zcfg->{datafile} . ": $!\n";
        my %flags = map { $_, 0 } @{ $zcfg->{flagdomains} };
        while (defined(my $line = <$zfile>)) {
            next unless $line =~ /^(\S+?)\.\s+/;
            if (exist($flags{$1})) {
                $flags{$1} = 1;
            }
        }
        if (scalar(grep { $flags{$_} } keys %flags) == scalar(keys %flags)) {
            return 1;    # File downloaded with all flag domains
        }
    }

    return 0;            # Got broken files from all servers
}

sub db_import_zone {
    my $self = shift;

    my $dbh = $self->dbh;
    open my $fh, '<', $self->cget(qw[zone datafile])
      or die "Failed to open zone file: $!\n";
    $dbh->begin_work;
    $dbh->do(q[delete from zone]);
    my $sth = $dbh->prepare(
        q[insert ignore into zone (name,ttl,class,type,data) values (?,?,?,?,?)]
    );
    while (defined(my $line = <$fh>)) {
        chomp($line);
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*;/;    # Skip comment lines
        my ($name, $ttl, $class, $type, $data) = split(/\s+/, $line, 5);
        $sth->execute($name, $ttl, $class, $type, $data);
    }
    $dbh->commit;
    $dbh->begin_work;
    $dbh->do(q[delete from domains]);
    $dbh->do(q[insert into domains(domain) select distinct name from zone where type = 'NS']);
    $dbh->do(q[update domains set domain = substr(domain,1,char_length(domain)-1)]);
    $dbh->commit;
}

1;
__END__

=head1 NAME

Zonestat::Prepare - preparatory tasks for statistics gathering

=head1 SYNOPSIS

  use Zonestat::Prepare;

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
