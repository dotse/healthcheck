use 5.008008;
use ExtUtils::MakeMaker;


WriteMakefile(
    NAME              => 'Zonestat',
    VERSION_FROM      => 'lib/Zonestat.pm', # finds $VERSION
    PREREQ_PM         => {
        YAML => 0,
        DNSCheck => 1.00,
        DBI => 0,
        DBD::mysql => 0,
        HTTP::Request => 0,
        DBIx::Class => 0.08112,
        Apache2::Request => 0,
        MasonX::Request::WithApacheSession => 0,
        IO::Socket::SSL => 0,
        Text::CSV_XS => 0,
        Geo::IP => 0,
        HTTP::Response => 5.824,
        CHI => 0,
    }, 
    ($] >= 5.005 ?     
      (ABSTRACT_FROM  => 'lib/Zonestat.pm', # retrieve abstract from module
       AUTHOR         => 'Calle Dybedahl <calle@init.se>') : ()),
);
