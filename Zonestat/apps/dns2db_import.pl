#!/opt/local/bin/perl

use warnings;
use strict;

use Zonestat;
use DBI;
use Getopt::Long;
use File::Path;
use Cwd;

my $debug;
my $workdir  = ".dns2db_import_$$";
my $tar      = 'tar';
my $startdir = getcwd();

GetOptions(
    'debug+'    => \$debug,
    'workdir=s' => \$workdir,
    'tar=s'     => \$tar,
);

my $dns2db = Zonestat->new->gather->dbx('Dns2db');

sub debug {
    if ($debug) {
        print STDERR @_;
    }
    print "\n";
}

sub ipv6stats_import {
    my ($date, $server, $d2d) = @_;
    my $name = "$date/ipv6stats_$date.db";
    my $dbh =
      DBI->connect("dbi:SQLite:dbname=$name", '', '', { RaiseError => 1 })
      or die "Failed to open $name: " . $DBI::errstr;
    debug "Using database $name";

    my $sth;
    eval { $sth = $dbh->prepare(q[SELECT * FROM stats]) };
    return if $@;

    $sth->execute;
    while (my $r = $sth->fetchrow_hashref) {
        $d2d->add_to_ipv6stats(
            {
                datum     => $r->{datum},
                tid       => $r->{tid},
                iptot     => $r->{iptot},
                ipv6total => $r->{ipv6total},
                ipv6aaaa  => $r->{ipv6aaaa},
                ipv6ns    => $r->{ipv6ns},
                ipv6mx    => $r->{ipv6mx},
                ipv6a     => $r->{ipv6a},
                ipv6soa   => $r->{ipv6soa},
                ipv6ds    => $r->{ipv6ds},
                ipv6a6    => $r->{ipv6a6},
                ipv4total => $r->{ipv4total},
                ipv4aaaa  => $r->{ipv4aaaa},
                ipv4ns    => $r->{ipv4ns},
                ipv4mx    => $r->{ipv4mx},
                ipv4a     => $r->{ipv4a},
                ipv4soa   => $r->{ipv4soa},
                ipv4ds    => $r->{ipv4ds},
                ipv4a6    => $r->{ipv4a6}
            }
        );
    }
}

sub topresolvers_import {
    my ($date, $server, $d2d) = @_;
    my $name = "$date/topresolvers$date.db";
    my $dbh =
      DBI->connect("dbi:SQLite:dbname=$name", '', '', { RaiseError => 1 })
      or die "Failed to open $name: " . $DBI::errstr;
    debug "Using database $name";

    my $sth;
    eval { $sth = $dbh->prepare(q[SELECT * FROM dnssum]); };
    return if $@;

    $sth->execute;
    while (my $r = $sth->fetchrow_hashref) {
        $d2d->add_to_topresolvers(
            {
                src    => $r->{src},
                qcount => $r->{qcount},
                dnssec => $r->{dnssec}
            }
        );
    }
}

sub v6as_import {
    my ($date, $server, $d2d) = @_;
    my $name = "$date/v6as$date.db";
    my $dbh =
      DBI->connect("dbi:SQLite:dbname=$name", '', '', { RaiseError => 1 })
      or die "Failed to open $name: " . $DBI::errstr;
    debug "Using database $name";

    my $sth;
    eval { $sth = $dbh->prepare(q[SELECT * FROM asnets]); };
    return if $@;

    $sth->execute;
    while (my $r = $sth->fetchrow_hashref) {
        $d2d->add_to_v6as(
            {
                foreign_id  => $r->{id},
                date        => $r->{date},
                count       => $r->{count},
                asname      => $r->{asname},
                country     => $r->{country},
                description => $r->{description}
            }
        );
    }
}

unless (-d $workdir) {
    debug "Creating $workdir";
    mkpath $workdir;
}

chdir $workdir;

foreach my $name (@ARGV) {
    my ($server, $date);

    if (($server, $date) = $name =~ m|([-A-Za-z.]+)(\d+)\.tgz$|) {
        if ($dns2db->search({ imported_at => $date, server => $server })
            ->count > 0)
        {
            print "Data already imported for $server at $date.\n";
            next;
        }

        my $d2d = $dns2db->create({ imported_at => $date, server => $server });

        system $tar, 'xzf', $name;
        v6as_import($date, $server, $d2d);
        topresolvers_import($date, $server, $d2d);
        ipv6stats_import($date, $server, $d2d);
    } else {
        print "Failed to parse filename: $name\n";
        exit(1);
    }
}

END {
    chdir $startdir;
    debug "Removing $workdir";
    rmtree $workdir;
}
