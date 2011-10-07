package Statweb::View::CSV;

use Moose;
use Text::CSV_XS;
use namespace::autoclean;

BEGIN { extends 'Catalyst::View' }

sub process {
    my ($self, $c) = @_;
    my $csv = Text::CSV_XS->new;
    my $res = '';
    my $filename = $c->stash->{filename};
    my $data = $c->stash->{data} || [];

    foreach my $r (@$data) {
        $csv->combine(@$r);
        $res .= $csv->string;
        $res .= "\n";
    }

    $c->res->content_type('text/comma-separated-values');
    $c->res->header('Content-Disposition',
        'attachment; filename="' . $filename . '.csv"');
    $c->res->body($res);
}

__PACKAGE__->meta->make_immutable;
1;