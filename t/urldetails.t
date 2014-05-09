#!/usr/bin/perl

# Copyright 2013 Jason Owen <jason.a.owen@gmail.com>

# This file is part of irssi-urldetails.

# irssi-urldetails is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# irssi-urldetails is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with irssi-urldetails.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Test::More 'no_plan';
use Test::MockObject;
use File::Slurp;
use XML::Simple;

my $server;
my $settings = {};
sub Irssi::MSGLEVEL_NOTICES { return 1; }
sub Irssi::settings_add_bool { return 1; }
sub Irssi::settings_get_bool {
  my ($setting) = @_;
  return $settings->{$setting};
}
sub Irssi::signal_add { return 1; }
sub Irssi::signal_continue {
  my ($line, $server, $window) = @_;
  $server->signal_continue($line, $server, $window);
}
sub Irssi::version { return 1; }
use UrlDetails;

sub message_prints {
  my ($message, $input, @expected) = @_;
  $server = MockServer::new();

  &$message($server, $input, "nickname", 'user@example.com', '#channel');

  is(scalar(@{$server->{messages}}), scalar(@expected), "prints correct number of messages");
  my $i = 0;
  foreach (@expected) {
    is($server->{messages}[$i++]->{message}, $_, "prints correct message");
  }
}

sub topic_prints {
  my ($topic, $input, @expected) = @_;
  $server = MockServer::new();

  &$topic($server, '#channel', $input, "nickname", 'user@example.com');

  is(scalar(@{$server->{messages}}), scalar(@expected), "prints correct number of messages");
  my $i = 0;
  foreach (@expected) {
    is($server->{messages}[$i++]->{message}, $_, "prints correct message");
  }
}

sub send_text_replaces {
  my ($send_text, $input, $expected) = @_;
  $server = MockServer::new();

  &$send_text($input, $server, { name => "window" });

  is(scalar(@{$server->{lines}}), 1, "prints correct number of lines");
  is($server->{lines}[0], $expected, "prints correct line");
}

sub url_detail_matcher {
  my ($pattern, $replacement, $detail, $should_canonicalize) = @_;
  my $matcher = MockMatcher->new($pattern, $replacement, $detail);
  $settings->{'urldetails_' . $matcher->canonicalize_setting_name()} = $should_canonicalize;
  return $matcher;
}

# message
my $message = UrlDetails::message(
  url_detail_matcher("foo", "foo", "bar"),
  url_detail_matcher("baz", "baz", "qux"),
);
message_prints($message, "nomatch");
message_prints($message, "foo", "bar");
message_prints($message, "baz", "qux");
message_prints($message, "foo baz", "bar", "qux");

# topic
my $topic = UrlDetails::topic(
  url_detail_matcher("foo", "foo", "bar"),
  url_detail_matcher("baz", "baz", "qux"),
);
topic_prints($topic, "nomatch");
topic_prints($topic, "foo", "bar");
topic_prints($topic, "baz", "qux");
topic_prints($topic, "foo baz", "bar", "qux");

# send_text
my $send_text = UrlDetails::send_text(
  url_detail_matcher("replaceself", "replaceself", "bar", 1),
  url_detail_matcher("baz", "quux", "qux", 1),
);
send_text_replaces($send_text, "nomatch", "nomatch");
send_text_replaces($send_text, "nomatch nomatch", "nomatch nomatch");
send_text_replaces($send_text, "replaceself", "replaceself");
send_text_replaces($send_text, "baz", "quux");
send_text_replaces($send_text, "baz baz", "quux quux");

$send_text = UrlDetails::send_text(
  url_detail_matcher("baz", "quux", "qux", 0),
);
send_text_replaces($send_text, "baz", "baz");

package MockMatcher;
use base ("UrlDetails");

sub new {
  my ($class, $pattern, $replacement, $detail) = @_;
  return bless({
    pattern => $pattern,
    replacement => $replacement,
    detail => $detail,
  });
}

sub contains_link {
  my ($self, $_) = @_;
  return /$self->{pattern}/;
}

sub details {
  my ($self) = @_;
  return $self->{detail};
}

sub canonical_link {
  my ($self, $_) = @_;
  return $self->{replacement};
}

sub canonicalize_setting_name {
  my ($self) = @_;
  return $self->{replacement};
}

package MockServer;

sub new {
  return bless({
    messages => [],
    lines => [],
  });
}

sub print {
  my ($self, $target, $message, $level) = @_;
  push (@{$self->{messages}}, {
    target => $target,
    message => $message,
    level => $level,
  });
}

sub signal_continue {
  my ($self, $line, $server, $window) = @_;
  push (@{$self->{lines}}, $line);
}
