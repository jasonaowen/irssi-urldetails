#!/usr/bin/perl
use strict;
use Test::SimpleUnit qw{:functions};
Test::SimpleUnit::AutoskipFailedSetup( 1 );

sub Irssi::signal_add { return 1; }
require "youtube.pl";

my %homepages = (
    "full link without video ID" => "http://www.youtube.com/",
    "short link without video ID" => "http://youtu.be/",
);
my $video_id = 'VjQMpBb1gps';
my $canonical_link = "https://youtu.be/$video_id";
my %links = (
  "short link with protocol" => "http://youtu.be/$video_id",
  "short link without protocol" => "youtu.be/$video_id",
  "full link with protocol" => "http://www.youtube.com/watch?v=$video_id",
  "full link without protocol" => "www.youtube.com/watch?v=$video_id",
  "full link without www" => "youtube.com/watch?v=$video_id",
  "full link with feature parameter" => "www.youtube.com/watch?v=$video_id&feature=youtu.be",
);
my $time = 't=17s';
my $canonical_time_link = "https://youtu.be/$video_id#$time";
my %time_links = (
  "short link with time anchor" => "http://youtu.be/$video_id#$time",
  "full link with time parameter" => "http://www.youtube.com/watch?v=$video_id&$time",
  "full link with time anchor" => "http://www.youtube.com/watch?v=$video_id#$time",
);
my %all_links = (%links, %time_links);

sub contains_test {
  my ($name, $url) = @_;
  return {
    name => "contains_youtube_link finds $name",
    test => sub {
        assert contains_youtube_link($url), "Failed to detect link";
    },
  };
}

sub contains_negative_test {
  my ($name, $url) = @_;
  return {
    name => "contains_youtube_link does not catch $name",
    test => sub {
        assertNot contains_youtube_link($url), "Improperly detected link";
    },
  };
}

sub get_video_id_test {
  my ($name, $url) = @_;
  return {
    name => "get_video_id parses $name",
    test => sub {
        assertEquals(get_video_id($url), $video_id, "Failed to find video id");
    },
  };
}

sub get_time_test {
  my ($name, $url) = @_;
  my $id = contains_youtube_link($url);
  return {
    name => "get_time finds time in $name",
    test => sub {
        assertEquals(get_time($url), $time, "Failed to find time");
    },
  };
}

sub get_time_negative_test {
  my ($name, $url) = @_;
  my $id = contains_youtube_link($url);
  return {
    name => "get_time does not find time in $name",
    test => sub {
        assertNot(get_time($url), "Improperly found time");
    },
  };
}

sub canonical_youtube_link_test {
  my ($canonical_url, $name, $url) = @_;
  return {
    name => "canonical_youtube_link builds correct URL for $name",
    test => sub {
        assertEquals(canonical_youtube_link($url), $canonical_url, "Incorrect URL produced");
    },
  };
}

sub equals {
  my ($func, $arg) = @_;
  return sub {
    return &$func($arg, @_);
  };
}

sub generate_tests {
  my ($generator, %links) = @_;
  my @tests = ();

  while (my($k, $v) = each %links) {
    push(@tests, &$generator($k, $v));
  }
  return @tests;
}

my @tests = (
  # contains_youtube_link
  generate_tests(\&contains_test, %all_links),
  generate_tests(\&contains_negative_test, %homepages),

  # get_video_id
  generate_tests(\&get_video_id_test, %all_links),

  # get_time
  generate_tests(\&get_time_test, %time_links),
  generate_tests(\&get_time_negative_test, %links),

  # canonical_youtube_link
  generate_tests(equals(\&canonical_youtube_link_test, $canonical_link), %links),
  generate_tests(equals(\&canonical_youtube_link_test, $canonical_time_link), %time_links),
);
runTests( @tests );
