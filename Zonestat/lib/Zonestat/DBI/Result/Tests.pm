package Zonestat::DBI::Result::Tests;
use base 'DBIx::Class';
use Date::Parse;
use POSIX qw[strftime];

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('tests');
__PACKAGE__->add_columns(
    qw[id domain source_id source_data count_critical count_error
      count_warning count_notice count_info],
    begin => { accessor => '_begin' },
    end   => { accessor => '_end' },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(results => 'Zonestat::DBI::Result::Results', 'test_id');
__PACKAGE__->belongs_to(source => 'Zonestat::DBI::Result::Source', 'source_id');
__PACKAGE__->belongs_to(
    tested_domain => 'Zonestat::DBI::Result::Domains',
    { 'foreign.domain' => 'self.domain' }
);
__PACKAGE__->belongs_to(testrun => 'Zonestat::DBI::Result::Testrun', 'run_id');

sub maybe_format {
    my ($formatted, $time) = @_;
    my $t = str2time($time);

    if ($formatted) {
        return strftime("%y-%m-%d %H:%M:%S", localtime($t));
    } else {
        return $t;
    }
}

sub begin {
    my $self      = shift;
    my $formatted = shift;

    return maybe_format($formatted, $self->_begin);
}

sub end {
    my $self      = shift;
    my $formatted = shift;

    return maybe_format($formatted, $self->_end);
}

1;
