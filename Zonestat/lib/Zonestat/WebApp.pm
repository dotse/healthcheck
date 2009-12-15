package Zonestat::WebApp;

use base 'MasonX::WebApp';

use Data::Dumper;
use Zonestat;

###
### Settings
###
__PACKAGE__->SessionWrapperParams(
    {
        cookie_domain  => '.cyberpomo.com',
        class          => 'Apache::Session::File',
        directory      => '/tmp/sessions/data',
        lock_directory => '/tmp/sessions/locks',
        use_cookie     => 1,
    }
);
__PACKAGE__->MasonGlobalName('$app');
__PACKAGE__->ActionURIPrefix('/action/');

###
### Stuff that gets run at every request
###
sub _init {
    my $self = shift;
    my $path = $self->apache_req->unparsed_uri;

    unless ($self->session->{user}
        or $path eq '/login.html'
        or $path eq '/action/login'
        or $path =~ m{^/(js|css)/})
    {
        $self->redirect(path => '/login.html');
    }
}

###
### Utility methods
###
our $zs = Zonestat->new;

sub testruns {
    my $self = shift;

    return map { $zs->dbx('Testrun')->find($_) }
      sort keys %{ $self->session->{testruns} };
}

###
### Commands that get called via urls that start with /action/
###

sub login {
    my $self = shift;
    my $args = $self->args;
    my $zs   = Zonestat->new;
    my $user;

    if (    $args->{username}
        and $args->{password}
        and $user = $zs->user($args->{username}, $args->{password}))
    {
        $self->session->{user} = $user->id;
        $self->redirect(path => '/');
    } else {
        $self->session->{user} = undef;
        $self->_add_error_message('Username and password does not match.');
        $self->session->{username} = $args->{username};
        $self->redirect(path => '/login.html');
    }
}

sub toggletestrun {
    my $self = shift;
    my $tid  = $self->args->{tid};

    my %trs = %{ $self->session->{testruns} };

    if ($trs{$tid}) {
        delete $trs{$tid};
    } else {
        $trs{$tid} = 1;
    }
    $self->session->{testruns} = \%trs;

    $self->redirect(path => '/');
}

1;
