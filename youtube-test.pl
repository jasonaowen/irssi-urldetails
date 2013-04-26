#!/usr/bin/perl
use strict;
use Test::SimpleUnit qw{:functions};
Test::SimpleUnit::AutoskipFailedSetup( 1 );

sub Irssi::signal_add { return 1; }
require "youtube.pl";

my $video_id = 'VjQMpBb1gps';
my %links = (
  "short link with protocol" => "http://youtu.be/$video_id",
  "short link without protocol" => "youtu.be/$video_id",
  "full link with protocol" => "http://www.youtube.com/watch?v=$video_id",
  "full link without protocol" => "www.youtube.com/watch?v=$video_id",
  "full link without www" => "youtube.com/watch?v=$video_id",
  "full link with feature parameter" => "www.youtube.com/watch?v=$video_id&feature=youtu.be",
  "full link with time parameter" => "http://www.youtube.com/watch?v=$video_id&t=17s",
);

sub generate_contains_test {
  my ($name, $url) = @_;
  return {
    name => "contains_youtube_link finds $name",
    test => sub {
        assert contains_youtube_link($url), "Failed to detect link";
    },
  };
}

sub generate_get_video_id_test {
  my ($name, $url) = @_;
  my $id = contains_youtube_link($url);
  return {
    name => "get_video_id parses $name",
    test => sub {
        assertEquals(get_video_id($url), $video_id, "Failed to find video id");
    },
  };
}

sub generate_tests {
  my ($generator) = @_;
  my @tests = ();

  while (my($k, $v) = each %links) {
    push(@tests, &$generator($k, $v));
  }
  return @tests;
}

my @tests = (
  # contains_youtube_link
  #generate_contains_tests(),
  generate_tests(\&generate_contains_test),
  {
    name => 'contains_youtube_link does not catch full link without video ID',
    test => sub {
        assertNot contains_youtube_link('http://www.youtube.com/'), "Improperly detected link";
    },
  },
  {
    name => 'contains_youtube_link does not catch short link without video ID',
    test => sub {
        assertNot contains_youtube_link('http://youtu.be/'), "Improperly detected link";
    },
  },

  # get_video_id
  generate_tests(\&generate_get_video_id_test),
);
runTests( @tests );

