#!/usr/bin/perl
use strict;
use Test::More 'no_plan';

sub Irssi::signal_add { return 1; }
require "urldetails.pl";

my $video_id = 'VjQMpBb1gps';
my $canonical_url = "https://youtu.be/$video_id";

my %homepages = (
    "full link without video ID" => "http://www.youtube.com/",
    "short link without video ID" => "http://youtu.be/",
);
my %embedded = (
  "embedded full link" => "http://example.com/youtube.com/watch?v=$video_id",
  "embedded short link" => "http://example.com/youtu.be/$video_id"
);
my %links = (
  "short link with protocol" => "http://youtu.be/$video_id",
  "short link without protocol" => "youtu.be/$video_id",
  "full link with protocol" => "http://www.youtube.com/watch?v=$video_id",
  "full link without protocol" => "www.youtube.com/watch?v=$video_id",
  "full link without www" => "youtube.com/watch?v=$video_id",
  "full link with feature parameter" => "www.youtube.com/watch?v=$video_id&feature=youtu.be",
);
my $time = 't=17s';
my $canonical_time_url = "https://youtu.be/$video_id#$time";
my %time_links = (
  "short link with time anchor" => "http://youtu.be/$video_id#$time",
  "full link with time parameter" => "http://www.youtube.com/watch?v=$video_id&$time",
  "full link with time anchor" => "http://www.youtube.com/watch?v=$video_id#$time",
);
my %all_links = (%links, %time_links);

# contains_youtube_link
while(my ($name, $url) = each %all_links) {
  ok(UrlDetails::YouTube::contains_youtube_link($url), "contains_youtube_link finds $name");
}
while(my ($name, $url) = each %homepages) {
  ok(!UrlDetails::YouTube::contains_youtube_link($url), "contains_youtube_link does not find $name");
}
while(my ($name, $url) = each %embedded) {
  ok(!UrlDetails::YouTube::contains_youtube_link($url), "contains_youtube_link does not find $name");
}

# get_video_id
while(my ($name, $url) = each %all_links) {
  is(UrlDetails::YouTube::get_video_id($url), $video_id, "get_video_id finds video id in $name");
}

# get_time
while(my ($name, $url) = each %time_links) {
  is(UrlDetails::YouTube::get_time($url), $time, "get_time finds time in $name");
}
while(my ($name, $url) = each %links) {
  ok(!UrlDetails::YouTube::get_time($url), "get_time does not find time in $name");
}

# canonical_youtube_link
while(my ($name, $url) = each %links) {
  is(UrlDetails::YouTube::canonical_youtube_link($url), $canonical_url, "canonical_youtube_link builds correct url for $name");
}
while(my ($name, $url) = each %time_links) {
  is(UrlDetails::YouTube::canonical_youtube_link($url), $canonical_time_url, "canonical_youtube_link builds correct url for $name");
}
