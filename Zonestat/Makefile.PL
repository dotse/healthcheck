use 5.008008;
use ExtUtils::MakeMaker;


WriteMakefile(
    NAME              => 'Zonestat',
    VERSION_FROM      => 'lib/Zonestat.pm', # finds $VERSION
    PREREQ_PM         => {
        YAML => 0,
        DNSCheck => 0.92,
        DBI => 0,
        DBD::mysql => 0,
        LWP::UserAgent => 0,
        DBIx::Class => 0,
    }, 
    ($] >= 5.005 ?     
      (ABSTRACT_FROM  => 'lib/Zonestat.pm', # retrieve abstract from module
       AUTHOR         => 'Calle Dybedahl <calle@init.se>') : ()),
);
