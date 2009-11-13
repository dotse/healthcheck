package Zonestat;

use 5.008008;
use strict;
use warnings;

use Config;

use Zonestat::Config;
use Zonestat::DBI;
use Zonestat::Common;
use Zonestat::Prepare;
use Zonestat::Gather;
use Zonestat::Present;
use Zonestat::User;

use Module::Find;

our $VERSION = '0.01';

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    unless (@_) {
        @_ = ($Config{siteprefix} . '/share/dnscheck/site_config.yaml');
    }

    $self->{conf}    = Zonestat::Config->new(@_);
    $self->{prepare} = Zonestat::Prepare->new($self);
    $self->{gather}  = Zonestat::Gather->new($self);
    $self->{present} = Zonestat::Present->new($self);
    
    $self->register_plugins;

    return $self;
}

sub plugins {
    my $self = shift;
    
    return @{$self->{plugins}};
}

sub register_plugins {
    my $self = shift;

    my @plugins = useall ZonestatPlugin;
    $self->{plugins} = [@plugins];

    foreach my $mod (@plugins) {
        my $dbinfo = $mod->table_info;

        my $dbh = $self->dbh;
        foreach my $name (keys %$dbinfo) {
            eval {
                my $sql = sprintf q[SELECT count(%s) FROM %s],
                  (keys %{ $dbinfo->{$name} })[0], $name;
                $dbh->do($sql);
            };
            my $error = $@;
            if ($error =~ m|Table '[^']+' doesn't exist|) {
                my $sql = sprintf 'CREATE TABLE `%s` (', $name;
                $sql .= join ', ',
                  map { '`' . $_ . '` ' . $dbinfo->{$name}{$_} }
                  keys %{ $dbinfo->{$name} };
                $sql .=
', id serial primary key, run_id bigint(20) unsigned not null, domain_id int(10) unsigned not null';
                $sql .=
", CONSTRAINT `${name}_domain` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE";
                $sql .=
", CONSTRAINT `${name}_testrun` FOREIGN KEY (`run_id`) REFERENCES `testruns` (`id`) ON DELETE CASCADE";
                $sql .= ') ENGINE=InnoDB DEFAULT CHARSET=utf8';
                eval { $dbh->do($sql); };
                if ($@) {
                    die "Failed to create table: $error\n";
                    exit(1);
                } else {
                    print "Created $name.\n";
                }
            } elsif ($error) {
                die "Database error: $error\n";
            }
        }

        $mod->register_dbix($self->schema);
    }

}

sub cget {
    my $self = shift;

    return $self->{conf}->get(@_);
}

sub prepare {
    my $self = shift;
    return $self->{prepare};
}

sub gather {
    my $self = shift;
    return $self->{gather};
}

sub present {
    my $self = shift;
    return $self->{present};
}

sub user {
    my $self = shift;
    my ($name_or_id, $pwd) = @_;

    my $user = Zonestat::User->new($self);
    if (defined($pwd)) {
        return $user->login($name_or_id, $pwd);
    } else {
        return $user->by_id($name_or_id);
    }
}

sub dbconfig {
    my $self = shift;

    return $self->{conf}->db;
}

sub dbh {
    my $self = shift;

    return $self->{dbh} if (defined($self->{dbh}) and $self->{dbh}->ping);

    my $dbh =
      DBI->connect($self->dbconfig,
        { RaiseError => 1, AutoCommit => 1, PrintError => 0 });
    die "Failed to connect to database: " . $DBI::errstr . "\n"
      unless defined($dbh);
    $self->{dbh} = $dbh;
    return $dbh;
}

sub schema {
    my $self = shift;

    $self->{schema} = Zonestat::DBI->connect($self->dbconfig)
      unless defined($self->{schema});

    return $self->{schema};
}

sub dbx {
    my $self = shift;
    my ($table) = @_;

    if (defined($table)) {
        return $self->schema->resultset($table);
    } else {
        return $self->schema;
    }
}

1;
__END__

=head1 NAME

Zonestat - gather and present statistics for a DNS zone

=head1 SYNOPSIS

  use Zonestat;

=head1 DESCRIPTION


=head1 SEE ALSO

L<DNSCheck>.

=head1 AUTHOR

Calle Dybedahl, E<lt>calle@init.seE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Calle Dybedahl

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.9 or,
at your option, any later version of Perl 5 you may have available.


=cut
