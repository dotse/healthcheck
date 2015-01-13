package Zonestat::Collect::Zonemaster;

use strict;
use warnings;

use Time::HiRes;

use Zonemaster;
use Zonemaster::Translator;

sub collect {
    my (undef, $domain,) = @_;
    
    return ('zonemaster', zonemaster($domain));
}

my $trans = Zonemaster::Translator->new;
my $zonemaster = Zonemaster->new;
my @locales = qw[sv_SE.UTF-8 en_US.UTF-8 fr_FR.UTF-8];

sub translate {
    my ( $entry ) = @_;
    my %res;

    foreach my $locale (@locales) {
        $trans->locale($locale);
        $res{$locale} = $trans->translate_tag($entry);
    }

    return \%res;
}

sub zonemaster {
    my ( $domain ) = @_;

    Zonemaster->test_zone($domain);
    my @msgs = map {
        {
            timestamp => $_->timestamp,
            tag => $_->tag,
            module => $_->module,
            level => $_->level,
            numeric_level => $_->numeric_level,
            args => $_->args,
            translations => translate($_),
        }
    } grep { $_->numeric_level >= 0 } @{Zonemaster->logger->entries};

    return \@msgs;
}

1;