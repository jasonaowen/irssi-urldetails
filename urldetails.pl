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

require Irssi;
use HTTP::Tiny;

our $VERSION = '0.01';
our %IRSSI = (
  authors     => 'Jason Owen',
  contact     => 'jason.a.owen@gmail.com',
  name        => 'URL Details',
  description => 'Print details of recognized incoming links ' .
                 'and canonicalize recognized outgoing links.',
  license     => 'GPLv3',
);

my $irssi_version = Irssi::version();
my $tiny = HTTP::Tiny->new((
  agent => "Irssi/$irssi_version Plugin($IRSSI{name})/$VERSION",
  timeout => 5,
));

my @url_types = (
  UrlDetails::isgd->new($tiny),
  UrlDetails::Vimeo->new($tiny),
  UrlDetails::YouTube->new($tiny),
);

my $setting_group = "urldetails";
foreach my $url_type (@url_types) {
  Irssi::settings_add_bool(
    $setting_group,
    $setting_group . "_" . $url_type->canonicalize_setting_name(),
    1
  );
}

Irssi::signal_add('message public', UrlDetails::message(@url_types));
Irssi::signal_add('send text', UrlDetails::send_text(@url_types));

package UrlDetails;
use Irssi;
use Number::Format 'format_number';
use Time::Duration;

sub message {
  my @url_types = @_;
  return sub {
    my ($server, $_, $nick, $mask, $target) = @_;
    return unless $server;

    foreach my $word (split) {
      foreach my $url_type (@url_types) {
        if ($url_type->contains_link($word)) {
          $server->print($target, $url_type->details($word), Irssi::MSGLEVEL_NOTICES);
        }
      }
    }
  }
}

sub send_text {
  my @url_types = @_;
  return sub {
    my ($_, $server, $window) = @_;
    return unless $window;
    my @words = ();

    foreach my $word (split) {
      foreach my $url_type (@url_types) {
        if ($url_type->contains_link($word)) {
          $server->print($window->{name}, $url_type->details($word), Irssi::MSGLEVEL_NOTICES);
          $word = $url_type->canonicalize($word);
        }
      }
      push(@words, $word);
    }
    my $line = join(" ", @words);
    Irssi::signal_continue($line, $server, $window);
  }
}

sub new {
  my ($class, $http) = @_;
  return bless({http => $http}, $class);
}

sub api_details {
  my ($self, $url) = @_;
  my $api_url = $self->get_api_url($url);
  my $response = $self->{http}->get($api_url);
  return $self->api_parse($response);
}

sub api_parse {
  my ($self, $response) = @_;
  if ($response->{success}) {
    return $self->api_parse_response($response->{content});
  } else {
    return join(" ", "API call failed:", $response->{status}, $response->{reason});
  }
}

sub canonicalize {
  my ($self, $word) = @_;
  if ($self->should_canonicalize()) {
    return $self->canonical_link($word);
  } else {
    return $word;
  }
}

sub should_canonicalize {
  my ($self) = @_;
  return Irssi::settings_get_bool(
    $setting_group . "_" . $self->canonicalize_setting_name()
  );
}

sub date {
  my ($self, $d) = @_;
  return substr($d, 0, 10);
}

sub number {
  my ($self, $n) = @_;
  return format_number($n);
}

sub time {
  my ($self, $seconds) = @_;
  return concise(duration($seconds));
}

package UrlDetails::YouTube;
use base ("UrlDetails");
use XML::Simple;

sub contains_link {
  (my $self, $_) = @_;
  return (contains_fulllink() or contains_shortlink())
}

sub contains_fulllink {
  return /^(?:https?:\/\/)?(?:www\.)?youtube\.com\/watch\?.+/;
}

sub contains_shortlink {
  return /^(?:https?:\/\/)?youtu\.be\/.+/;
}

sub get_video_id {
  (my $self, $_) = @_;
  if (contains_shortlink()) {
    return get_video_id_from_shortlink();
  } else {
    return get_video_id_from_fulllink();
  }
}

sub get_video_id_from_shortlink {
  /youtu\.be\/([A-Za-z0-9_-]{11})/;
  return $1;
}

sub get_video_id_from_fulllink {
  /v=([A-Za-z0-9_-]{11})/;
  return $1;
}

sub get_time {
  (my $self, $_) = @_;
  /(t=[0-9smh]+)/;
  return $1;
}

sub canonical_link {
  my ($self, $word) = @_;
  my $video_id = $self->get_video_id($word);
  my $link = "https://youtu.be/$video_id";
  my $time = $self->get_time($word);
  if ($time) {
    $link .= "#$time";
  }
  return $link;
}

sub get_api_url {
  my ($self, $url) = @_;
  my $video_id = $self->get_video_id($url);
  return "https://gdata.youtube.com/feeds/api/videos/$video_id?v=2";
}

sub xml_title {
  my ($self, $xml) = @_;
  return $xml->{"title"};
}

sub xml_time {
  my ($self, $xml) = @_;
  return $self->time($xml->{"media:group"}->{"yt:duration"}->{"seconds"});
}

sub xml_date {
  my ($self, $xml) = @_;
  return $self->date($xml->{"published"});
}

sub xml_views {
  my ($self, $xml) = @_;
  return $self->number($xml->{"yt:statistics"}->{"viewCount"});
}

sub api_parse_response {
  my ($self, $content) = @_;
  my $xml = XMLin($content);
  return (
    $self->xml_title($xml),
    $self->xml_time($xml),
    $self->xml_date($xml),
    $self->xml_views($xml),
  );
}

sub details {
  my ($self, $word) = @_;
  return "-YouTube- " . join(" | ",
    $self->canonical_link($word),
    $self->api_details($word)
  );
}

sub canonicalize_setting_name {
  return "canonicalize_youtube"
}

package UrlDetails::Vimeo;
use base ("UrlDetails");
use XML::Simple;

sub contains_link {
  (my $self, $_) = @_;
  return /^(?:https?:\/\/)?(?:www\.)?vimeo\.com\/[0-9]+/;
}

sub get_video_id {
  (my $self, $_) = @_;
  /\/([0-9]+)/;
  return $1;
}

sub canonical_link {
  my ($self, $url) = @_;
  my $video_id = $self->get_video_id($url);
  return "https://vimeo.com/$video_id";
}

sub details {
  my ($self, $url) = @_;
  return "-Vimeo- " . join(" | ",
    $self->canonical_link($url),
    $self->api_details($url)
  );
}

sub get_api_url {
  my ($self, $url) = @_;
  my $video_id = $self->get_video_id($url);
  return "https://vimeo.com/api/v2/video/$video_id.xml";
}

sub api_parse_response {
  my ($self, $content) = @_;
  my $xml = XMLin($content);
  return (
    $self->xml_title($xml),
    $self->xml_time($xml),
    $self->xml_date($xml),
    $self->xml_views($xml),
  );
}

sub xml_title {
  my ($self, $xml) = @_;
  return $xml->{"video"}->{"title"};
}

sub xml_time {
  my ($self, $xml) = @_;
  return $self->time($xml->{"video"}->{"duration"});
}

sub xml_date {
  my ($self, $xml) = @_;
  return $self->date($xml->{"video"}->{"upload_date"});
}

sub xml_views {
  my ($self, $xml) = @_;
  return $self->number($xml->{"video"}->{"stats_number_of_plays"});
}

sub canonicalize_setting_name {
  return "canonicalize_vimeo"
}

package UrlDetails::isgd;
use base ("UrlDetails");
use XML::Simple;

sub contains_link {
  (my $self, $_) = @_;
  return (contains_isgd_link() or contains_vgd_link());
}

sub contains_isgd_link {
  return /^(?:http:\/\/)?(?:www\.)?is\.gd\/.+/;
}

sub contains_vgd_link {
  return /^(?:http:\/\/)?(?:www\.)?v\.gd\/.+/;
}

sub canonical_link {
  my ($self, $url) = @_;
  my $base_url = $self->get_base_url($url);
  my $url_id = $self->get_url_id($url);
  return "$base_url/$url_id";
}

sub get_base_url {
  (my $self, $_) = @_;
  if (contains_isgd_link()) {
    return 'http://is.gd';
  } else {
    return 'http://v.gd';
  }
}

sub get_url_id {
  (my $self, $_) = @_;
  /\.gd\/(.+)/;
  return $1;
}

sub details {
  my ($self, $url) = @_;
  my $link = $self->canonical_link($url);
  my $full_link = $self->api_details($url);
  return "-is.gd- $link -> $full_link";
}

sub get_api_url {
  my ($self, $url) = @_;
  my $base_url = $self->get_base_url($url);
  my $url_id = $self->get_url_id($url);
  return "$base_url/forward.php?shorturl=$url_id&format=xml";
}

sub api_parse_response {
  my ($self, $content) = @_;
  my $xml = XMLin($content);
  if ($xml->{url}) {
    return $self->xml_full_url($xml);
  } else {
    return "Not found";
  }
}

sub xml_full_url {
  my ($self, $xml) = @_;
  return $xml->{"url"};
}

sub canonicalize_setting_name {
  return "canonicalize_isgd"
}
