#!/usr/bin/perl
use strict;
use warnings;
use Test::More 'no_plan';
use Test::MockObject;
use File::Slurp;
use XML::Simple;
use Data::Dumper;

my $server;
sub Irssi::signal_add { return 1; }
sub Irssi::MSGLEVEL_NOTICES { return 1; }
sub Irssi::signal_continue {
  my ($line, $server, $window) = @_;
  $server->signal_continue($line, $server, $window);
}
require "urldetails.pl";

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

sub send_text_replaces {
  my ($send_text, $input, $expected) = @_;
  $server = MockServer::new();

  &$send_text($input, $server, { name => "window" });

  is(scalar(@{$server->{lines}}), 1, "prints correct number of lines");
  is($server->{lines}[0], $expected, "prints correct line");
}

sub url_detail_matcher {
  my ($pattern, $replacement, $detail) = @_;
  my $mock = Test::MockObject->new();
  $mock->mock('contains_link', sub {
    my ($self, $_) = @_;
    return /$pattern/;
  });
  $mock->mock('details', sub {
    return $detail;
  });
  $mock->mock('canonical_link', sub {
    my ($self, $_) = @_;
    return (/$pattern/)? $replacement : $_;
  });
  return $mock;
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

# send_text
my $send_text = UrlDetails::send_text(
  url_detail_matcher("replaceself", "replaceself", "bar"),
  url_detail_matcher("baz", "quux", "qux"),
);
send_text_replaces($send_text, "nomatch", "nomatch");
send_text_replaces($send_text, "nomatch nomatch", "nomatch nomatch");
send_text_replaces($send_text, "replaceself", "replaceself");
send_text_replaces($send_text, "baz", "quux");
send_text_replaces($send_text, "baz baz", "quux quux");

package MockServer;

sub new {
  return bless({
    messages => [],
    lines => [],
  });
}

sub print {
  my ($self, $target, $message, $level) = @_;
  push ($self->{messages}, {
    target => $target,
    message => $message,
    level => $level,
  });
}

sub signal_continue {
  my ($self, $line, $server, $window) = @_;
  push ($self->{lines}, $line);
}
