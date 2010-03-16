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

    unless ($check->dbh) {
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
    my $dbh;

    eval { $dbh = $check->dbh; };
    if ($@) {
        slog 'critical', 'Database not available. Exiting.';
        exit(1);
    }

    $dbh->do(
q[UPDATE queue SET inprogress = NULL WHERE inprogress IS NOT NULL AND tester_pid IS NULL]
    );
    my $c = $dbh->selectall_hashref(
q[SELECT id, domain, tester_pid FROM queue WHERE inprogress IS NOT NULL AND tester_pid IS NOT NULL],
        'tester_pid'
    );
    foreach my $k (keys %$c) {
        if (kill 0, $c->{$k}{tester_pid}) {

      # The process running this test is still alive, so just remove it from the
      # queue.
            $dbh->do(q[DELETE FROM queue WHERE id = ?], undef, $c->{$k}{id});
            slog 'info', 'Removed %s from queue', $c->{$k}{domain};
        } else {

            # The process running this test has died, so reschedule it
            $dbh->do(q[UPDATE queue SET inprogress = NULL WHERE id = ?],
                undef, $c->{$k}{id});
            slog 'info', 'Rescheduled test for %s', $c->{$k}{domain};
        }
    }
}

################################################################
# Dispatcher
################################################################

sub dispatch {
    my $domain;
    my $id;
    my $source;
    my $source_data;
    my $fake_glue;
    my $priority;

    if (scalar keys %running < $limit) {
        ($domain, $id, $source, $source_data, $fake_glue, $priority) =
          get_entry();
        slog 'debug', "Fetched $domain from database." if defined($domain);
    } else {

        # slog 'info', 'Process limit reached.';
    }

    if (defined($domain)) {
        unless (defined($problem{$domain}) and $problem{$domain} >= 5) {
            process($domain, $id, $source, $source_data, $fake_glue, $priority);
        } else {
            slog 'error',
"Testing $domain caused repeated abnormal termination of children. Assuming bug. Exiting.";
            $running = 0;
        }
        return
          0.0
          ;  # There was something in the queue, so check for more without delay
    } else {
        return 0.25;    # Queue empty or process slots full. Wait a little.
    }
}

sub get_entry {
    my $dbh;

    eval { $dbh = $check->dbh; };
    if ($@) {
        slog 'critical', 'Database not available. Exiting.';
        exit(1);
    }

    my ($id, $domain, $source, $source_data, $fake_glue, $priority);

    eval {
        $dbh->begin_work;
        ($id, $domain, $source, $source_data, $fake_glue, $priority) =
          $dbh->selectrow_array(
q[SELECT id, domain, source_id, source_data, fake_parent_glue, priority FROM queue WHERE inprogress IS NULL AND priority = (SELECT MAX(priority) FROM queue WHERE inprogress IS NULL) ORDER BY id ASC LIMIT 1 FOR UPDATE]
          );
        slog 'debug', "Got $id, $domain from database."
          if (defined($domain) or defined($id));
        $dbh->do(q[UPDATE queue SET inprogress = NOW() WHERE id = ?],
            undef, $id);
        $dbh->commit;
    };
    if ($@) {
        my $err = $@;
        slog 'warning', "Database error in get_entry: $err";

        if ($err =~
/(DBD driver has not implemented the AutoCommit attribute)|(Lost connection to MySQL server during query)/
            and defined($id))
        {

            # Database handle went away. Try to recover.
            slog 'info',
              "Known problem. Trying to clear inprogress for queue id $id.";
            $dbh = $check->dbh;
            $dbh->do(q[UPDATE queue SET inprogress = NULL WHERE id = ?],
                undef, $id);
        }

        if ($err =~ m|Already in a transaction|) {
            slog 'critical',
              'Serious problem. Sleeping, then trying to restart.';
            $running = 0;
            $restart = 1;
            sleep(15);
            return;
        }

        return undef;
    }

    return ($domain, $id, $source, $source_data, $fake_glue, $priority);
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
    my $dc  = DNSCheck->new({ with_config_object => $check->config });
    my $dbh = $dc->dbh;
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

    $dbh->do(q[UPDATE queue SET tester_pid = ? WHERE id = ?], undef, $$, $id);
    $dbh->do(
q[INSERT INTO tests (domain,begin, source_id, source_data, run_id) VALUES (?,NOW(),?,?,?)],
        undef, $domain, $source, $source_data, $source_data
    );

    my $test_id = $dbh->{'mysql_insertid'};
    slog 'debug', "$$ running test number $test_id.";
    my $line = 0;

    # These lines hides all the actual useful work.
    $dc->zone->test($domain);

    my $sth = $dbh->prepare(
        q[
        INSERT INTO results
          (test_id,line,module_id,parent_module_id,timestamp,level,message,
          arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9)
          VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ]
    );
    while (defined(my $e = $log->get_next_entry)) {
        next if ($levels{ $e->{level} } < $levels{$savelevel});
        $line++;
        my $time = strftime("%Y-%m-%d %H:%M:%S", localtime($e->{timestamp}));
        $sth->execute(
            $test_id,               $line,        $e->{module_id},
            $e->{parent_module_id}, $time,        $e->{level},
            $e->{tag},              $e->{arg}[0], $e->{arg}[1],
            $e->{arg}[2],           $e->{arg}[3], $e->{arg}[4],
            $e->{arg}[5],           $e->{arg}[6], $e->{arg}[7],
            $e->{arg}[8],           $e->{arg}[9],
        );
    }

    $zs->gather->get_server_data($source_data, $domain);
    $zs->gather->from_plugins($source_data, $domain);

    # End of useful work

    $dbh->do(
q[UPDATE tests SET end = NOW(), count_critical = ?, count_error = ?, count_warning = ?, count_notice = ?, count_info = ?
  WHERE id = ?],
        undef, $log->count_critical, $log->count_error, $log->count_warning,
        $log->count_notice, $log->count_info, $test_id
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

    if (defined($exit_timeout) and time() - $exit_timeout > 300) {
        %running = ();
    }

    foreach my $pid (keys %start_time) {
        if ((gettimeofday() - $start_time{$pid}) > 180) {
            slog 'warning', "Child $pid timed out, killing it.";
            kill 9, $pid;
        }
    }
}

sub cleanup {
    my $domain   = shift;
    my $exitcode = shift;
    my $pid      = shift;
    my $dbh;

    eval { $dbh = $check->dbh; };
    if ($@) {
        slog 'critical', "Cannot connect to database. Exiting.";
        exit(1);
    }

    my $status = $exitcode >> 8;
    my $signal = $exitcode & 127;

    if ($status == 0) {

        # Child died nicely.
      AGAIN: eval {
            $dbh->do(q[DELETE FROM queue WHERE domain = ? AND tester_pid = ?],
                undef, $domain, $pid);
        };
        if ($@)
        { # mysqld dumped us. Get a new handle and try again, after a little pause
            slog 'warning',
              "Failed to delete queue entry for $domain. Retrying.";
            sleep(0.25);
            $dbh = $check->dbh;
            goto AGAIN;
        }

    } else {

        # Child blew up. Clean up.
        $problem{$domain} += 1;
        slog 'warning', "Unclean exit when testing $domain (status $status).";
        $dbh->do(q[UPDATE queue SET inprogress = NULL WHERE domain = ?],
            undef, $domain);
        $dbh->do(
q[DELETE FROM tests WHERE begin IS NOT NULL AND end IS NULL AND domain = ?],
            undef, $domain
        );
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
