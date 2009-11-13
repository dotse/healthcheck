package ZonestatPlugin::Example::DBIx;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw[Core]);
__PACKAGE__->table('plugin_example');
__PACKAGE__->add_columns(qw[id namelength]);
__PACKAGE__->set_primary_key('id');

package ZonestatPlugin::Example;

use 5.008009;
use strict;
use warnings;

our $VERSION = '0.01';

our $parent;

sub table_info {
    return { plugin_example => { namelength => 'int(10)', something  => 'text'} };
}

sub register_dbix {
    my $self = shift;
    $parent = shift;
    
    $parent->schema->register_class('ExamplePlugin', 'ZonestatPlugin::Example::DBIx');
}

sub gather {
    my ($self, $domain, $testrun) = @_;

   my $db = $parent->dbx('ExamplePlugin');
    $db->create({
        namelength => length($domain->domain),
        run_id => $testrun->id,
        domain_id => $domain->id
    });
}

sub as_html {
    my ($self, @tr) = @_;

}

1;
