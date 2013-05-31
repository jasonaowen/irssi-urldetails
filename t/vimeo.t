#!/usr/bin/perl
use strict;
use Test::More 'no_plan';
use Test::MockObject;
use File::Slurp;
use XML::Simple;

sub Irssi::settings_add_bool { return 1; }
sub Irssi::signal_add { return 1; }
sub Irssi::version { return 1; }
require "urldetails.pl";

# data to use in tests
my $video_id = '65102146';
my $video_title = '"Two Chips" / An Animated Short';
my $canonical_url = "https://vimeo.com/$video_id";
my $video_duration = '1m44s';
my $video_date = '2013-04-29';
my $video_views = '2,106,632';
my $details = "-Vimeo- $canonical_url | $video_title | $video_duration | $video_date | $video_views";

my %homepages = (
    "insecure link without video ID" => "http://www.vimeo.com/",
    "secure link without video ID" => "https://www.vimeo.com/",
    "insecure short link without video ID" => "http://vimeo.com/",
    "secure short link without video ID" => "https://vimeo.com/",
);
my %embedded = (
  "embedded link" => "http://example.com/vimeo.com/$video_id",
);
my %links = (
  "short link with protocol" => "http://vimeo.com/$video_id",
  "short link without protocol" => "vimeo.com/$video_id",
  "full link with protocol" => "http://www.vimeo.com/$video_id",
  "full link without protocol" => "www.vimeo.com/$video_id",
  "full link without www" => "vimeo.com/$video_id",
);
my $xml = read_file("t/$video_id.xml");

# build object to test
my $http_success = Test::MockObject->new();
$http_success->mock('get', sub { return {
  success => 1,
  content => $xml,
}; });
my $vimeo = UrlDetails::Vimeo->new($http_success);

# contains_link
while(my ($name, $url) = each %links) {
  ok($vimeo->contains_link($url), "contains_link finds $name");
}
while(my ($name, $url) = each %homepages) {
  ok(!$vimeo->contains_link($url), "contains_link does not find $name");
}
while(my ($name, $url) = each %embedded) {
  ok(!$vimeo->contains_link($url), "contains_link does not find $name");
}

# get_video_id
while(my ($name, $url) = each %links) {
  is($vimeo->get_video_id($url), $video_id, "get_video_id finds video id in $name");
}

# canonical_link
while(my ($name, $url) = each %links) {
  is($vimeo->canonical_link($url), $canonical_url, "canonical_link builds correct url for $name");
}

# xml parsing
my $parsed_xml = XMLin($xml);
is($vimeo->xml_title($parsed_xml), $video_title, "xml_title extracts correct title");
is($vimeo->xml_time($parsed_xml), $video_duration, "xml_time extracts correct duration");
is($vimeo->xml_date($parsed_xml), $video_date, "xml_date extracts correct date");
is($vimeo->xml_views($parsed_xml), $video_views, "xml_views extract correct number of views");

# details
while(my ($name, $url) = each %links) {
  is($vimeo->details($url), $details, "details for $name");
}
