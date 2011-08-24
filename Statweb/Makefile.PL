#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;

name 'Statweb';
all_from 'lib/Statweb.pm';

requires 'Catalyst::Runtime' => '5.80015';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'parent';
requires 'Config::General'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats
requires 'Zonestat';
requires (qw[
            Catalyst::Plugin::Session
            Catalyst::Plugin::Session::Store::FastMmap
            Catalyst::Plugin::Session::State::Cookie

            Catalyst::Plugin::Authentication

            Catalyst::View::TT

            Time::HiRes
            Data::Dumper
            List::Util
            Text::CSV_XS
            ]);

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
