#!/usr/bin/perl
#
# $Id: $
#
# Copyright (c) 2007 .SE (The Internet Infrastructure Foundation).
#                    All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
######################################################################
use 5.008;

use warnings;
use strict;

use DNSCheck;
use Zonestat;

use Getopt::Long;
use Sys::Syslog;
use POSIX qw(:sys_wait_h strftime);
use Time::HiRes qw(sleep gettimeofday);

use vars qw[
  %running
  %reaped
  %start_time
  %problem
  %killed
  $debug
  $verbose
  $check
  $zs
  $limit
  $running
  $restart
  @saved_argv
  $syslog
  $exit_timeout
  $savelevel
  %levels
];

%running    = ();
%reaped     = ();
%start_time = ();
%problem    = ();
%killed     = ();
$debug      = 0;
$verbose    = 0;
$check      = DNSCheck->new;
$zs         = Zonestat->new(%{ $check->config });
$limit      = $check->config->get("daemon")->{maxchild};
$savelevel  = $check->config->get("daemon")->{savelevel} || 'INFO';
$running    = 1;
$restart    = 0;
$syslog     = 1;
%levels     = (
    DEBUG    => 0,
    INFO     => 1,
    NOTICE   => 2,
    WARNING  => 3,
    ERROR    => 4,
    CRITICAL => 5,
);

# Kick everything off
main();

################################################################
# Utility functions and program setup
################################################################

# Log something. Far, far more complex than it should have to be, to keep from
# dying if we suddenly lose contact with syslogd. Which we do if the system is
# too heavily loaded.
sub slog {
    my $priority = shift;
    my $tries    = 0;

    # See perldoc on sprintf for why we have to write it like this
    my $msg = sprintf($_[0], @_[1 .. $#_]);

    printf("%s (%d): %s\n", uc($priority), $$, $msg) if $debug;

  TRY:
    eval {
        if ($syslog)
        {
            syslog($priority, @_);
        } else {
            printf STDERR "%s (%d): %s\n", uc($priority), $$, $msg;
        }
    };
    if ($@) {
        if ($tries < 5) {
            print STDERR "Trying to reconnect to syslogd...\n";
            sleep(0.5);
            $tries += 1;
            openlog($check->config->get("syslog")->{ident},
                'pid', $check->config->get("syslog")->{facility});
            goto TRY;
        } else {
            print STDERR
              "SYSLOG CONNECTION LOST. Switching to stderr logging.\n";
            $syslog = 0;
            printf STDERR "%s (%d): %s\n", uc($priority), $$, $msg;
        }
    }
}

sub setup {
    my $errfile = $check->config->get("daemon")->{errorlog};
    my $pidfile = $check->config->get("daemon")->{pidfile};

    @saved_argv = @ARGV;    # We'll use this if we're asked to restart ourselves
    GetOptions('debug' => \$debug, 'verbose' => \$verbose);
    openlog($check->config->get("syslog")->{ident},
        'pid', $check->config->get("syslog")->{facility});
    slog 'info', "$0 starting with %d maximum children.",
      $check->config->get("daemon")->{maxchild};
    slog 'info', 'IPv4 disabled.' unless $check->config->get("net")->{ipv4};
    slog 'info', 'IPv6 disabled.' unless $check->config->get("net")->{ipv6};
    slog 'info', 'SMTP disabled.' unless $check->config->get("net")->{smtp};
    slog 'info', 'Logging as %s to facility %s.',
      $check->config->get("syslog")->{ident},
      $check->config->get("syslog")->{facility};
    slog 'info', 'Reading config from %s and %s.',
      $check->config->get("configfile"), $check->config->get("siteconfigfile");

    unless ($zs->dbh) {
        die "Failed to connect to database. Exiting.\n";
    }
    detach() unless $debug;
    open STDERR, '>>', $errfile or die "Failed to open error log: $!";
    printf STDERR "%s starting at %s\n", $0, scalar(localtime);
    open PIDFILE, '>', $pidfile or die "Failed to open PID file: $!";
    print PIDFILE $$;
    close PIDFILE;
    $SIG{CHLD} = \&REAPER;
    $SIG{TERM} = sub { $running = 0 };
    $SIG{HUP}  = sub {
        $running = 0;
        $restart = 1;
    };
}

sub detach {

   # Instead of using ioctls and setfoo calls we use the old double-fork method.
    my $pid;

    # Once...
    $pid = fork;
    exit if $pid;
    die "Fork failed: $!" unless defined($pid);

    # ...and again
    $pid = fork;
    exit if $pid;
    die "Fork failed: $!" unless defined($pid);
    slog('info', 'Detached.');
}

# Clean up residue from earlier run(s), if any.
sub inital_cleanup {
    eval { $zs->dbh; };
    if ($@) {
        slog 'critical', 'Database not available. Exiting.';
        exit(1);
    }

    my $queue = $zs->dbx('Queue');

    $queue->search(
        {
            inprogress => { '!=', undef },
            tester_pid => undef,
        }
    )->update({ inprogress => undef });

    my $c = $queue->search(
        {
            inprogress => { '!=', undef },
            tester_pid => { '!=', undef },
        }
    );
    foreach my $k ($c->all) {
        if (kill 0, $k->tester_pid) {

      # The process running this test is still alive, so just remove it from the
      # queue.
            $k->delete;
            slog 'info', 'Removed %s from queue', $k->domain;
        } else {

            # The process running this test has died, so reschedule it
            $k->update({ inprogress => undef });
            slog 'info', 'Rescheduled test for %s', $k->domain;
        }
    }
}

################################################################
# Dispatcher
################################################################

sub dispatch {
    my @entries;

    if (scalar keys %running < $limit) {
        @entries = get_entries($limit - scalar keys %running);
    }

    if (@entries) {
        foreach my $e (@entries) {
            unless (defined($problem{ $e->domain })
                and $problem{ $e->domain } >= 5)
            {
                process($e->domain, $e->id, $e->source_id, $e->source_data,
                    $e->fake_parent_glue, $e->priority);
            } else {
                slog 'error',
                    "Testing "
                  . $e->domain
                  . " caused repeated abnormal termination of children. Assuming bug. Exiting.";
                $running = 0;
            }
        }
    }
    return 1.0;
}

sub get_entries {
    my ($entries_to_get) = @_;

    my $queue = $zs->dbx('Queue');
    my @entries;

    eval {
        my $max_prio =
          $queue->search({ inprogress => undef, })->get_column('priority')->max;
        return unless $max_prio;
        @entries = $queue->search(
            {
                inprogress => undef,
                priority   => $max_prio,
            },
            {
                order_by => { -asc => 'id' },
                rows     => $entries_to_get,
            }
        )->all;
        $queue->search({ id => { in => [map { $_->id } @entries] }, })
          ->update({ inprogress => \'NOW()' });
    };
    if ($@) {
        print STDERR "DBIx::Class did not help us...\n";
        die($@);
    }

    if (@entries) {
        return @entries;
    } else {
        return;
    }
}

sub process {
    my $domain      = shift;
    my $id          = shift;
    my $source      = shift;
    my $source_data = shift;
    my $fake_glue   = shift;
    my $priority    = shift;

    my $pid = fork;

    if ($pid) {    # True values, so parent
        $running{$pid}    = $domain;
        $start_time{$pid} = gettimeofday();
        slog 'debug', "Child process $pid has been started.";
    } elsif ($pid == 0) {    # Zero value, so child
        running_in_child($domain, $id, $source, $source_data, $fake_glue,
            $priority);
    } else {                 # Undefined value, so error
        die "Fork failed: $!";
    }
}

sub running_in_child {
    my $domain      = shift;
    my $id          = shift;
    my $source      = shift;
    my $source_data = shift;
    my $fake_glue   = shift;
    my $priority    = shift;

    # Reuse the old configuration, but get new everything else.
    my $dc = DNSCheck->new({ with_config_object => $check->config });
    my $log = $dc->logger;

    setpriority(0, $$, 20 - 2 * $priority);

    if (defined($fake_glue)) {
        my @ns = split(/\s+/, $fake_glue);
        foreach my $n (@ns) {
            my ($name, $ip) = split(m|/|, $n);
            $dc->add_fake_glue($domain, $name, $ip);
        }
    }

   # On some OS:s (including Ubuntu Linux), this is visible in the process list.
    $0 = "dispatcher: gathering $domain (queue id $id)";

    $zs->dbx('Queue')->find($id)->update({ tester_pid => $$ });
    my $test = $zs->dbx('Tests')->create(
        {
            domain      => $domain,
            source_id   => $source,
            begin       => \'NOW()',
            source_data => $source_data,
            run_id      => $source_data
        }
    );

    slog 'debug', "$$ running test number " . $test->id . ".\n";
    my $line = 0;

    # These lines hide all the actual useful work.
    slog 'debug', "Running DNSCheck tests for $domain.";
    $dc->zone->test($domain);
    $dc->log_nameserver_times;

    my @tmp_results;
    while (defined(my $e = $log->get_next_entry)) {
        next if ($levels{ $e->{level} } < $levels{$savelevel});
        push @tmp_results,
          {
            line             => ++$line,
            module_id        => $e->{module_id},
            parent_module_id => $e->{parent_module_id},
            timestamp =>
              strftime("%Y-%m-%d %H:%M:%S", localtime($e->{timestamp})),
            level   => $e->{level},
            message => $e->{tag},
            arg0    => $e->{arg}[0],
            arg1    => $e->{arg}[1],
            arg2    => $e->{arg}[2],
            arg3    => $e->{arg}[3],
            arg4    => $e->{arg}[4],
            arg5    => $e->{arg}[5],
            arg6    => $e->{arg}[6],
            arg7    => $e->{arg}[7],
            arg8    => $e->{arg}[8],
            arg9    => $e->{arg}[9],
            test_id => $test->id,
          };
    }
    $zs->dbx('Results')->populate(\@tmp_results);

    slog 'debug', "Getting server data for $domain.";
    $zs->gather->get_server_data($source_data, $domain);
    $zs->gather->from_plugins($source_data, $domain);

    # End of useful work

    $test->update(
        {
            end            => \'NOW()',
            count_critical => $log->count_critical,
            count_error    => $log->count_error,
            count_warning  => $log->count_warning,
            count_notice   => $log->count_notice,
            count_info     => $log->count_info,
        }
    );

# Everything went well, so exit nicely (if they didn't go well, we've already died not-so-nicely).
    slog 'debug', "$$ about to exit nicely.";
    exit(0);
}

################################################################
# Child process handling
################################################################

sub monitor_children {
    my @pids = keys
      %reaped;    # Can't trust %reaped to stay static while we work through it

    foreach my $pid (@pids) {
        slog 'debug', "Child process $pid has died.";

        my $domain   = $running{$pid};
        my $exitcode = $reaped{$pid};
        delete $running{$pid};
        delete $reaped{$pid};
        delete $start_time{$pid};
        cleanup($domain, $exitcode, $pid);
    }

    if (defined($exit_timeout) and time() - $exit_timeout > 900) {
        %running = ();
    }

    foreach my $pid (keys %start_time) {
        if ((gettimeofday() - $start_time{$pid}) > 900 and not $killed{$pid}) {
            slog 'warning', "Child $pid timed out, killing it.";
            kill 9, $pid;
            $killed{$pid} = time;
        }
    }
}

sub cleanup {
    my $domain   = shift;
    my $exitcode = shift;
    my $pid      = shift;
    my $queue    = $zs->dbx('Queue');
    my $tests    = $zs->dbx('Tests');

    my $status = $exitcode >> 8;
    my $signal = $exitcode & 127;

    if ($status == 0) {

        # Child died nicely.
      AGAIN: eval {
            $queue->search({ domain => $domain, tester_pid => $pid })->delete;
        };
        if ($@)
        { # mysqld dumped us. Get a new handle and try again, after a little pause
            slog 'warning',
              "Failed to delete queue entry for $domain. Retrying.\n   $@";
            sleep(0.25);
            goto AGAIN;
        }

    } else {

        # Child blew up. Clean up.
        $problem{$domain} += 1;
        slog 'warning', "Unclean exit when testing $domain (status $status).";
        $queue->search({ domain => $domain })->update({ inprogress => undef });
        $tests->search(
            {
                begin  => { '!=', undef },
                end    => undef,
                domain => $domain,
            }
        )->delete;
    }
}

# This code is mostly stolen from the perlipc manpage.
sub REAPER {
    my $child;

    while (($child = waitpid(-1, WNOHANG)) > 0) {
        $reaped{$child} = $?;
    }
    $SIG{CHLD} = \&REAPER;
}

################################################################
# Main program
################################################################

sub main {
    setup();
    inital_cleanup();
    while ($running) {
        my $skip = dispatch();
        monitor_children();
        sleep($skip);
    }
    slog 'info', "Waiting for %d children to exit.", scalar keys %running;
    $exit_timeout = time();
    monitor_children until (keys %running == 0);
    unlink $check->config->get("daemon")->{pidfile};
    slog 'info', "$0 exiting normally.";
    printf STDERR "%s exiting normally.\n", $0;
    if ($restart) {
        slog 'info', 'Attempting to restart myself.';
        exec($0, @saved_argv);
        warn "Exec failed: $!";
    }
}

__END__

=head1 NAME

dnscheck-dispatcher - daemon program to run tests from a database queue

=head2 SYNOPSIS

    dnscheck-dispatcher [--debug]
    
=head2 DESCRIPTION

This daemon puts itself into the background (unless the --debug flag is given)
and repeatedly queries the table C<queue> in the configured database for
domains to test. When it gets one, it spawns a new process to run the tests.
If there are no domains to check, or if the configured maximum number of
active child processes has been reached, it sleeps 0.25 seconds and then tries
again. It keeps doing this until it is terminated by a SIGTERM. At that point,
it will wait until all children have died and cleanups been performed before it
removes its PID file and then exits.

=head2 OPTIONS

=over

=item --debug

Prevents the daemon from going into the background and duplicates log
information to standard output (it still goes to syslog as well).

=back

=head1 CONFIGURATION

L<dnscheck-dispatcher> shares configuration files with the L<DNSCheck> perl
modules. Or, to be more precise, it creates such an object and then queries
its configuration object for its configuration information. It also uses the
L<DNSCheck> object to get its database connection.

There are two keys in the configuration YAML files that are of interest for
the dispatcher. The first one is C<syslog>. It has the subkeys C<ident>, which
specifies the name the daemon will use when talking to syslogd, and
C<facility>, which specifies the syslog facility to use.

The second one is C<daemon>. It has the subkeys C<pidfile>, C<errorlog>,
C<maxchild> and C<savelevel>. They specify, in order, the file where the
daemon will write its PID after it has detached, the file it will redirect its
standard error to, the maximum number of concurrent child processes it may
have and the minumum log level to save to the database. Make sure to set the
pathnames to values where the user the daemon is running under has write
permission, since it will terminated if they are specified but can't be
written to. Additionally, running with a maxchild value of n means that at
least n+1 simultaneous connections to the database will be opened. Make sure
that the database can actually handle that, or everything will die with more
or less understandable error messages.

If everything works as intended nothing should ever be written to the
errorlog. All normal log outout goes to syslog (and, with the debug flag,
standard output).
