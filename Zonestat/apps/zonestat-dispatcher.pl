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
  %qid
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
%qid        = ();
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
    $zs->gather->reset_inprogress;
}

################################################################
# Dispatcher
################################################################

sub dispatch {
    my @entries;

    if (scalar keys %running < $limit) {
        @entries = $zs->gather->get_from_queue($limit - scalar keys %running);
    }

    if (@entries) {
        foreach my $e (@entries) {
            unless (defined($problem{ $e->{domain} })
                and $problem{ $e->{domain} } >= 5)
            {
                process($e->{domain}, $e->{id}, $e->{source_id},
                    $e->{source_data}, $e->{fake_parent_glue},
                    $e->{priority});
            } else {
                slog 'error',
                    "Testing "
                  . $e->{domain}
                  . " caused repeated abnormal termination of children. Assuming bug. Exiting.";
                $running = 0;
            }
        }
    }
    return 1.0;
}

sub process {
    my $domain = shift;
    my $id     = shift;

    # The rest for later use.
    my $source      = shift;
    my $source_data = shift;
    my $fake_glue   = shift;
    my $priority    = shift;

    my $pid = fork;

    if ($pid) {    # True values, so parent
        $running{$pid}    = $domain;
        $qid{$pid}        = $id;
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
    my $domain = shift;
    my $id     = shift;

    # The rest will used at some later point.
    my $source      = shift;
    my $source_data = shift;
    my $fake_glue   = shift;
    my $priority    = shift;

    setpriority(0, $$, 2 * $priority);
    my $dbdoc = $zs->gather->set_active($id, $$);
    $0 = "dispatcher: gathering $domain (queue id $id)";

   # On some OS:s (including Ubuntu Linux), this is visible in the process list.

    slog 'debug', "$$ running queue id " . $id;

    # These lines hide all the actual useful work.
    slog 'debug', "Running DNSCheck tests for $domain.";
    $zs->gather->single_domain(
        $domain,
        {
            source  => $source,
            testrun => $source_data,
        }
    );

   # Everything went well, so exit nicely (if they didn't go well, we've already
   # died not-so-nicely). Also, remove from database queue.
    $dbdoc->delete;
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
        my $qid      = $qid{$pid};
        delete $running{$pid};
        delete $qid{$pid};
        delete $reaped{$pid};
        delete $start_time{$pid};
        cleanup($domain, $exitcode, $pid, $qid);
    }

    if (defined($exit_timeout) and time() - $exit_timeout > 900) {
        %running = ();
    }

    foreach my $pid (keys %start_time) {
        if ((gettimeofday() - $start_time{$pid}) > 900 and not $killed{$pid}) {
            slog 'warning', "Child $pid timed out, killing and requeueing it.";
            kill 9, $pid;
            $killed{$pid} = time;
            unless ($zs->gather->requeue($qid{$pid})) {
                slog 'warning',
                  "Child $pid requeued too many times. Entry ".$qid{$pid}." removed.";
            }
        }
    }
}

sub cleanup {
    my $domain   = shift;
    my $exitcode = shift;
    my $pid      = shift;
    my $qid      = shift;

    my $status = $exitcode >> 8;
    my $signal = $exitcode & 127;

    if ($status == 0) {

        # Child died nicely. So we don't need to do anything.
    } else {

        # Child blew up. Clean up.
        $problem{$domain} += 1;
        slog 'warning', "Unclean exit when testing $domain (status $status).";
        $zs->gather->reset_queue_entry($qid);
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
