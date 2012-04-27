#!/usr/bin/env perl

use lib 'blib/lib';

use Zonestat;
use File::Slurp;
use JSON::XS;

# my $dbc = Zonestat->new('t/Config')->dbconn;
# foreach my $db (@{$dbc->listDBs}) {
#     my $i = $db->dbInfo;
#     next unless $i->{db_name} =~ /^zonestat/;
# 
#     my $ddocs = $db->listDesignDocs;
#     map {$_->retrieve} @$ddocs;
# 
#     $db->delete;
#     $db->create;
#     
#     foreach my $doc (@$ddocs) {
#         delete $doc->{rev};
#         $doc->create;
#     }
# }

my $fix = decode_json(read_file('t/fixtures.json'));
foreach my $dbname (keys %$fix) {
    print "$dbname\n";
    foreach my $data (@{$fix->{$dbname}}) {
        print $data->{id} . "\n"
    }
}
