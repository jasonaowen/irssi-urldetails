use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use HTTP::Tiny;

$VERSION = '0.01';
%IRSSI = (
  authors     => 'Jason Owen',
  contact     => 'jason.a.owen@gmail.com',
  name        => 'URL Details',
  description => 'Print details of recognized incoming links ' .
                 'and canonicalize recognized outgoing links.' .
  license     => 'GPLv3',
);

my $tiny = HTTP::Tiny->new((
  agent => "$IRSSI{name}/$VERSION",
  timeout => 5,
));

my @url_types = (
  UrlDetails::isgd::new($tiny),
  UrlDetails::Vimeo::new($tiny),
  UrlDetails::YouTube::new($tiny),
);

Irssi::signal_add('message public', UrlDetails::message(@url_types));
Irssi::signal_add('send text', UrlDetails::send_text(@url_types));

package UrlDetails;

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
          $word = $url_type->canonical_link($word);
        }
      }
      push(@words, $word);
    }
    my $line = join(" ", @words);
    Irssi::signal_continue($line, $server, $window);
  }
}

package UrlDetails::YouTube;
use Number::Format 'format_number';
use XML::Simple;

sub new {
  my ($http) = @_;
  return bless({http => $http});
}

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
  my ($self, $video_id) = @_;
  return "https://gdata.youtube.com/feeds/api/videos/$video_id?v=2";
}

sub xml_title {
  my ($xml) = @_;
  return $xml->{"title"};
}

sub xml_date {
  my ($xml) = @_;
  return substr($xml->{"published"}, 0, 10);
}

sub xml_views {
  my ($xml) = @_;
  return format_number($xml->{"yt:statistics"}->{"viewCount"});
}

sub api_parse {
  my ($self, $response) = @_;
  if ($response->{success}) {
    my $xml = XMLin($response->{content});
    return (
      xml_title($xml),
      xml_date($xml),
      xml_views($xml),
    );
  } else {
    return join(" ", "API call failed:", $response->{status}, $response->{reason});
  }
}

sub api_details {
  my ($self, $word) = @_;
  my $video_id = $self->get_video_id($word);
  my $api_url = $self->get_api_url($video_id);
  my $response = $self->{http}->get($api_url);
  return $self->api_parse($response);
}

sub details {
  my ($self, $word) = @_;
  return "-YouTube- " . join(" | ",
    $self->canonical_link($word),
    $self->api_details($word)
  );
}

package UrlDetails::Vimeo;
use Number::Format 'format_number';
use XML::Simple;

sub new {
  my ($http) = @_;
  return bless({http => $http});
}

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

sub api_details {
  my ($self, $url) = @_;
  my $video_id = $self->get_video_id($url);
  my $api_url = $self->get_api_url($video_id);
  my $response = $self->{http}->get($api_url);
  return $self->api_parse($response);
}

sub get_api_url {
  my ($self, $video_id) = @_;
  return "https://vimeo.com/api/v2/video/$video_id.xml";
}

sub api_parse {
  my ($self, $response) = @_;
  if ($response->{success}) {
    my $xml = XMLin($response->{content});
    return (
      $self->xml_title($xml),
      $self->xml_date($xml),
      $self->xml_views($xml),
    );
  } else {
    return join(" ", "API call failed:", $response->{status}, $response->{reason});
  }
}

sub xml_title {
  my ($self, $xml) = @_;
  return $xml->{"video"}->{"title"};
}

sub xml_date {
  my ($self, $xml) = @_;
  return substr($xml->{"video"}->{"upload_date"}, 0, 10);
}

sub xml_views {
  my ($self, $xml) = @_;
  return format_number($xml->{"video"}->{"stats_number_of_plays"});
}

package UrlDetails::isgd;
use XML::Simple;

sub new {
  my ($http) = @_;
  return bless({http => $http});
}

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

sub api_details {
  my ($self, $url) = @_;
  my $api_url = $self->get_api_url($url);
  my $response = $self->{http}->get($api_url);
  return $self->api_parse($response);
}

sub get_api_url {
  my ($self, $url) = @_;
  my $base_url = $self->get_base_url($url);
  my $url_id = $self->get_url_id($url);
  return "$base_url/forward.php?shorturl=$url_id&format=xml";
}

sub api_parse {
  my ($self, $response) = @_;
  if ($response->{success}) {
    my $xml = XMLin($response->{content});
    return $self->xml_full_url($xml);
  } else {
    return join(" ", "API call failed:", $response->{status}, $response->{reason});
  }
}

sub xml_full_url {
  my ($self, $xml) = @_;
  return $xml->{"url"};
}
