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
use Test::More 'no_plan';
use Test::MockObject;
use File::Slurp;

sub Irssi::settings_add_bool { return 1; }
sub Irssi::signal_add { return 1; }
sub Irssi::version { return 1; }
use UrlDetails;

# data to use in tests
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
my $xml = read_file("t/$video_id.xml");
my $details = "-YouTube- $canonical_url | Chewbacca Music Video (Clerks) | 1m47s | 2006-10-04 | 1,162,324";
my $time_details = "-YouTube- $canonical_time_url | Chewbacca Music Video (Clerks) | 1m47s | 2006-10-04 | 1,162,324";

# build object to test
my $http_success = Test::MockObject->new();
$http_success->mock('get', sub { return {
  success => 1,
  content => $xml,
}; });
my $youtube = UrlDetails::YouTube->new($http_success);

# contains_link
while(my ($name, $url) = each %all_links) {
  ok($youtube->contains_link($url), "contains_link finds $name");
}
while(my ($name, $url) = each %homepages) {
  ok(!$youtube->contains_link($url), "contains_link does not find $name");
}
while(my ($name, $url) = each %embedded) {
  ok(!$youtube->contains_link($url), "contains_link does not find $name");
}

# get_video_id
while(my ($name, $url) = each %all_links) {
  is($youtube->get_video_id($url), $video_id, "get_video_id finds video id in $name");
}

# get_time
while(my ($name, $url) = each %time_links) {
  is($youtube->get_time($url), $time, "get_time finds time in $name");
}
while(my ($name, $url) = each %links) {
  ok(!$youtube->get_time($url), "get_time does not find time in $name");
}

# canonical_link
while(my ($name, $url) = each %links) {
  is($youtube->canonical_link($url), $canonical_url, "canonical_link builds correct url for $name");
}
while(my ($name, $url) = each %time_links) {
  is($youtube->canonical_link($url), $canonical_time_url, "canonical_link builds correct url for $name");
}

# details
while(my ($name, $url) = each %links) {
  is($youtube->details($url), $details, "details for $name");
}
while(my ($name, $url) = each %time_links) {
  is($youtube->details($url), $time_details, "details for $name");
}
