#!/usr/bin/perl
use strict;
use Test::More 'no_plan';
use Test::MockObject;
use File::Slurp;
use XML::Simple;

sub Irssi::command_bind { return 1; }
sub Irssi::signal_add { return 1; }
sub Irssi::version { return 1; }
require "urldetails.pl";

# data to use in tests
my $isgd_url_id = 'example';
my $isgd_url_full = 'http://www.example.com';
my $isgd_canonical_url = "http://is.gd/$isgd_url_id";
my $isgd_details = "-is.gd- $isgd_canonical_url -> $isgd_url_full";
my $isgd_xml = read_file('t/isgd.example.xml');

my $vgd_url_id = 'example';
my $vgd_url_full = 'http://example.com';
my $vgd_canonical_url = "http://v.gd/$vgd_url_id";
my $vgd_details = "-is.gd- $vgd_canonical_url -> $vgd_url_full";
my $vgd_xml = read_file('t/vgd.example.xml');

my %homepages = (
    "is.gd link without url ID" => "http://www.is.gd/",
    "is.gd short link without url ID" => "http://is.gd/",
    "v.gd link without url ID" => "http://www.v.gd/",
    "v.gd short link without url ID" => "http://v.gd/",
);
my %embedded = (
  "embedded is.gd link" => "http://example.com/is.gd/$isgd_url_id",
  "embedded v.gd link" => "http://example.com/v.gd/$vgd_url_id",
);
my %isgd_links = (
  "is.gd short link with protocol" => "http://is.gd/$isgd_url_id",
  "is.gd short link without protocol" => "is.gd/$isgd_url_id",
  "is.gd full link with protocol" => "http://www.is.gd/$isgd_url_id",
  "is.gd full link without protocol" => "www.is.gd/$isgd_url_id",
);
my %vgd_links = (
  "v.gd short link with protocol" => "http://v.gd/$vgd_url_id",
  "v.gd short link without protocol" => "v.gd/$vgd_url_id",
  "v.gd full link with protocol" => "http://www.v.gd/$vgd_url_id",
  "v.gd full link without protocol" => "www.v.gd/$vgd_url_id",
);
my %all_links = (%isgd_links, %vgd_links);

# build object to test
my $isgd_http = Test::MockObject->new();
$isgd_http->mock('get', sub { return {
  success => 1,
  content => $isgd_xml,
}; });
my $isgd = UrlDetails::isgd->new($isgd_http);

my $vgd_http = Test::MockObject->new();
$vgd_http->mock('get', sub { return {
  success => 1,
  content => $vgd_xml,
}; });
my $vgd = UrlDetails::isgd->new($vgd_http);

# contains_link
while(my ($name, $url) = each %all_links) {
  ok($isgd->contains_link($url), "contains_link finds $name");
}
while(my ($name, $url) = each %homepages) {
  ok(!$isgd->contains_link($url), "contains_link does not find $name");
}
while(my ($name, $url) = each %embedded) {
  ok(!$isgd->contains_link($url), "contains_link does not find $name");
}

# canonical_link
while(my ($name, $url) = each %isgd_links) {
  is($isgd->canonical_link($url), $isgd_canonical_url, "canonical_link builds correct url for $name");
}
while(my ($name, $url) = each %vgd_links) {
  is($isgd->canonical_link($url), $vgd_canonical_url, "canonical_link builds correct url for $name");
}

# xml parsing
my $isgd_parsed_xml = XMLin($isgd_xml);
is($isgd->xml_full_url($isgd_parsed_xml), $isgd_url_full, "xml_full_url extracts correct url");

my $vgd_parsed_xml = XMLin($vgd_xml);
is($vgd->xml_full_url($vgd_parsed_xml), $vgd_url_full, "xml_full_url extracts correct url");

# details
while(my ($name, $url) = each %isgd_links) {
  is($isgd->details($url), $isgd_details, "details for $name");
}
while(my ($name, $url) = each %vgd_links) {
  is($vgd->details($url), $vgd_details, "details for $name");
}
