package Zonestat::Prepare;

use 5.008008;
use strict;
use warnings;
use POSIX 'strftime';
use Carp;

use LWP::UserAgent;
use IO::Uncompress::Gunzip;
use File::Temp 'tempfile';
use Data::Dumper;

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
            if (exists($flags{$1})) {
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
    my $dsg = $self->dbx('Dsgroup')->find_or_create({ name => '.se' });
    my $ds  = $dsg->create_related('domainsets', {});

    open my $fh, '<', $self->cget(qw[zone datafile])
      or die "Failed to open zone file: $!\n";
    $dbh->begin_work;
    $dbh->do(q[delete from zone]);
    my $sth = $dbh->prepare(
        q[insert into zone (name,ttl,class,type,data) values (?,?,?,?,?)]);
    while (defined(my $line = <$fh>)) {
        chomp($line);
        next if $line =~ /^\s*$/;
        next if $line =~ /^\s*;/;    # Skip comment lines
        my ($name, $ttl, $class, $type, $data) = split(/\s+/, $line, 5);
        $sth->execute($name, $ttl, $class, $type, $data);
    }
    $dbh->commit;
    $dbh->begin_work;
    foreach my $dname (
        map { $_->[0] } @{
            $dbh->selectall_arrayref(
                q[select distinct name from zone where type = 'NS'])
        }
      )
    {
        $dname =~ s/\.$//;
        $dbh->do(
q[INSERT INTO domains (domain) VALUES (?) ON DUPLICATE KEY UPDATE last_import = now()],
            undef, $dname
        );
        my $id =
          $dbh->selectall_arrayref(q[SELECT id FROM domains WHERE domain = ?],
            undef, $dname);
        $dbh->do(
            q[INSERT INTO domain_set_glue (domain_id, set_id) VALUES (?,?)],
            undef, $id->[0][0], $ds->id);
    }
    $dbh->commit;
}

sub create_random_set {
    my $self = shift;

    my $ds = $self->dbx('Dsgroup')->find({ name => '.se' })->active_set;
    croak 'Failed to find dsgroup .se' unless $ds;
    my $rd =
      $self->dbx('Dsgroup')->find({ name => 'Random' })->add_to_domainsets({});
    croak 'Failed to create new domainset in Random group' unless $rd;
    my $domains = $ds->search_related('domains',
        {},
        {
            order_by => \'rand()',
            rows     => 10000,
        }
    );

    while (my $d = $domains->next) {
        $rd->add_to_domains($d);
    }

    return $rd;
}

sub update_asn_table_from_ripe {
    my $self = shift;

    # ftp://ftp.ripe.net/ripe/dbase/split/ripe.db.aut-num.gz
    my $url = 'ftp://ftp.ripe.net/ripe/dbase/split/ripe.db.aut-num.gz';
    my ($fh, $fname) = tempfile();

    my $ua  = LWP::UserAgent->new;
    my $res = $ua->request(
        HTTP::Request->new(GET => $url),
        sub {
            my ($chunk) = @_;
            print $fh $chunk;
        }
    );
    seek $fh, 0, 0;

    my $db = $self->dbx('Asdata');
    $db->delete;
    my ($asn, $asname, $asdescr) = (undef, '', '');
    my $gz = IO::Uncompress::Gunzip->new($fh);
    while (my $line = $gz->getline) {
        if ($line =~ /^aut-num:\s+AS(\w+)/) {
            if (defined($asn)) {
                chomp($asdescr);
                $db->create(
                    { asn => $asn, asname => $asname, descr => $asdescr });
                $asn     = undef;
                $asname  = '';
                $asdescr = '';
            }
            $asn = $1;
        } elsif ($line =~ /^as-name:\s+([^#\n]+)$/) {
            $asname = $1;
        } elsif ($line =~ /^descr:\s+(.*)$/) {
            $asdescr .= "\t$1\n";
        } else {

            # print "[$line]\n";
        }
    }
    unlink $fname or die $!;
}

# The following is pretty much the entire content of Steffen Ullrich's
# Net::INET6Glue::FTP module. It's Cut-and-pasted into here due to .SE's
# restrictions on using modules off of CPAN on production servers. If the
# module and its siblings ever show up in Ubuntu's package repository, we can
# remove this as well as some hideous code in DNSCheck::Test::SMTP.

BEGIN {
    use Net::FTP;    # tested with version 2.77
    use Socket;
    use Carp 'croak';

    # implement EPRT
    sub Net::FTP::_EPRT {
        shift->command("EPRT", @_)->response() == Net::FTP::CMD_OK;
    }

    sub Net::FTP::eprt {
        @_ == 1 || @_ == 2 or croak 'usage: $ftp->eprt([PORT])';
        my ($ftp, $port) = @_;
        delete ${*$ftp}{net_ftp_intern_port};
        unless ($port) {
            my $listen = ${*$ftp}{net_ftp_listen} ||= IO::Socket::INET6->new(
                Listen    => 1,
                Timeout   => $ftp->timeout,
                LocalAddr => $ftp->sockhost,
            );
            ${*$ftp}{net_ftp_intern_port} = 1;
            $port = "|2|" . $listen->sockhost . "|" . $listen->sockport . "|";
        }
        my $ok = $ftp->_EPRT($port);
        ${*$ftp}{net_ftp_port} = $port if $ok;
        return $ok;
    }

    # implement EPSV
    sub Net::FTP::_EPSV {
        shift->command("EPSV", @_)->response() == Net::FTP::CMD_OK;
    }

    sub Net::FTP::epsv {
        my $ftp = shift;
        @_ and croak 'usage: $ftp->epsv()';
        delete ${*$ftp}{net_ftp_intern_port};

        $ftp->_EPSV && $ftp->message =~ m{\(([\x33-\x7e])\1\1(\d+)\1\)}
          ? ${*$ftp}{'net_ftp_pasv'} = $2
          : undef;
    }

    {

        # redefine PORT and PASV so that they use EPRT and EPSV if necessary
        no warnings 'redefine';
        my $old_port = \&Net::FTP::port;
        *Net::FTP::port = sub {
            goto &$old_port if $_[0]->sockdomain == AF_INET or @_ < 1 or @_ > 2;
            goto &Net::FTP::eprt;
        };

        my $old_pasv = \&Net::FTP::pasv;
        *Net::FTP::pasv = sub {
            goto &$old_pasv if $_[0]->sockdomain == AF_INET or @_ < 1 or @_ > 2;
            goto &Net::FTP::epsv;
        };

        # redefined _dataconn to make use of the data it got from EPSV
        # copied and adapted from Net::FTP::_dataconn
        my $old_dataconn = \&Net::FTP::_dataconn;
        *Net::FTP::_dataconn = sub {
            goto &$old_dataconn if $_[0]->sockdomain == AF_INET;
            my $ftp = shift;

            my $pkg = "Net::FTP::" . $ftp->type;
            eval "require $pkg";
            $pkg =~ s/ /_/g;
            delete ${*$ftp}{net_ftp_dataconn};

            my $data;
            if (my $port = ${*$ftp}{net_ftp_pasv}) {
                $data = $pkg->new(
                    PeerAddr  => $ftp->peerhost,
                    PeerPort  => $port,
                    LocalAddr => ${*$ftp}{net_ftp_localaddr},
                );
            } elsif (my $listen = delete ${*$ftp}{net_ftp_listen}) {
                $data = $listen->accept($pkg);
                close($listen);
            }

            return if !$data;

            $data->timeout($ftp->timeout);
            ${*$ftp}{net_ftp_dataconn} = $data;
            ${*$data}                  = "";
            ${*$data}{net_ftp_cmd}     = $ftp;
            ${*$data}{net_ftp_blksize} = ${*$ftp}{net_ftp_blksize};
            return $data;
        };
    }

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
