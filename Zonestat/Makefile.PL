use 5.008009;
use ExtUtils::MakeMaker;


WriteMakefile(
    NAME              => 'Zonestat',
    VERSION_FROM      => 'lib/Zonestat.pm', # finds $VERSION
    PREREQ_PM         => {
        YAML => 0,
        DNSCheck => 1.3,
        HTTP::Request => 0,
        IO::Socket::SSL => 0,
        Text::CSV_XS => 0,
        Geo::IP => 0,
        HTTP::Response => 5.824,
        XML::Simple => 0,
        CouchDB::Client => 0.10,
        CouchDB::Helper => 0,
        Config::Any => 0.18,
        JSON::XS => 0,
        Net::LibIDN => 0,
        Try::Tiny => 0,
    }, 
    ($] >= 5.005 ?     
      (ABSTRACT_FROM  => 'lib/Zonestat.pm', # retrieve abstract from module
       AUTHOR         => 'Calle Dybedahl <calle@init.se>') : ()),
);

sub MY::postamble {
    return <<EOF;
coverage:
	cover -delete
	HARNESS_PERL_SWITCHES=-MDevel::Cover=+ignore,Mock make test
	cover
EOF
}
