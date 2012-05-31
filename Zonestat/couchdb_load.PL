#!/opt/local/bin/perl

use strict;
use warnings;

use Cwd;
use CouchDB::Client;
use File::Slurp qw[slurp read_dir];
use File::stat;
use File::Slurp;
use Cwd;

install_to_couchdb($ENV{COUCHDB_URL} || 'http://127.0.0.1:5984/');

sub get_content_of {
    my $name = shift;
    my $stat = stat($name);

    if (-f $name) {
        return {
            stat    => $stat,
            content => scalar(read_file($name)),
            type    => 'file',
        };
    } elsif (-d $name) {
        my %res;
        my $cwd = cwd();
        opendir my $d, $name or die "$name: $!";
        $res{stat} = $stat;
        $res{type} = 'dir';
        chdir($name);
        foreach my $f (grep { $_ ne '.' and $_ ne '..' } readdir $d) {
            $res{content}{$f} = get_content_of($f);
        }
        chdir($cwd);
        return \%res;
    } else {
        return {
            stat    => $stat,
            content => '<non-handled file type>',
            type    => 'other',
        };
    }
}

sub max_mtime {
    my $tree = shift;
    my $max  = 0;

    foreach my $t (keys %$tree) {
        next if $t eq '_rev';
        if ($tree->{$t}{type} eq 'file') {
            $max = $tree->{$t}{stat}->mtime if $tree->{$t}{stat}->mtime > $max;
        } elsif ($tree->{$t}{type} eq 'dir') {
            my $tmp = max_mtime($tree->{$t}{content});
            $max = $tmp if $tmp > $max;
        }
    }

    return $max;
}

sub prune_tree {
    my $node = shift;

    if (!ref($node)) {
        return $node;
    } elsif (ref($node) eq 'HASH') {
        my %res;

        while (my ($name, $tree) = each %$node) {
            $name =~ s/\.js$//;
            $res{$name} = prune_tree($tree->{content});
        }
        return \%res;
    } else {
        die "Strange node type: " . ref($node);
    }
}

sub build_design_docs {
    my $dir = shift || 'couchdb';
    my $tree = get_content_of($dir);
    my @ddocs;
    my @res;

    while (my ($database, $subtree) = each %{ $tree->{content} }) {
        while (my ($docname, $doctree) =
            each %{ $subtree->{content}{_design}{content} })
        {
            push @ddocs,
              {
                database => $database,
                id       => '_design/' . $docname,
                tree     => $doctree->{content}
              };
        }
    }

    foreach my $doc (@ddocs) {
        if (!defined($doc->{tree}{_rev}) or max_mtime($doc->{tree}) > $doc->{tree}{_rev}{stat}->mtime) {
            push @res,
              {
                database => $doc->{database},
                id       => $doc->{id},
                content  => prune_tree($doc->{tree})
              };
        }
    }

    return @res;
}

sub store_to_db {
    my ($conn, $doc, $prefix_from, $prefix_to) = @_;
    my $diskname = $doc->{database};
    my $dbname = $doc->{database};
    if ($prefix_to and $prefix_from) {
        $dbname =~ s/$prefix_from/$prefix_to/g;
    }

    my $id     = $doc->{id};
    my $db     = $conn->newDB($dbname);

    if (!$conn->dbExists($dbname)) {
        $db->create;
    }

    my $dbdoc = $db->newDoc($id, $doc->{content}{_rev});
    if ($db->docExists($id)) {
        $dbdoc->retrieve;
    } else {
        $dbdoc->create;
    }
    $dbdoc->data($doc->{content});
    print "Uploading " . $dbname . '/' . $id . "\n";
    $dbdoc->update;

    my $topdir   = cwd();
    my $filename = $topdir . '/couchdb/' . $diskname . '/' . $id . '/_rev';
    open my $fh, '>', $filename
      or die "Failed to open _rev file $filename: $!\n";
    print $fh $dbdoc->rev;
    close $fh;
}

sub install_to_couchdb {
    my $url      = shift || $ENV{COUCHDB_URL} || 'http://127.0.0.1:5984';
    my $arg = shift || {};

    my $username = $arg->{username} || $ENV{COUCHDB_USERNAME};
    my $password = $arg->{password} || $ENV{COUCHDB_PASSWORD};
    my $realm    = $arg->{realm}    || $ENV{COUCHDB_REALM};
    my $prefix   = $arg->{prefix_transform};
    my ($prefix_from, $prefix_to);

    if ($prefix) {
        ($prefix_from, $prefix_to) = split(/\|/, $prefix);
        unless ($prefix_from and $prefix_to) {
            die "The prefix_transform argument must be of the form 'from_string|to_string'.\n";
        }
    }

    my @ddocs = build_design_docs();

    my $conn = CouchDB::Client->new(
        uri      => $url,
        username => $username,
        password => $password,
        realm    => $realm
    );
    unless ($conn->testConnection) {
        warn "Failed to connect to database. Design document upload not performed.\n";
        exit(0);
    }

    foreach my $doc (@ddocs) {
        store_to_db($conn, $doc, $prefix_from, $prefix_to);
    }
}
