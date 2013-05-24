use strict;
use vars qw($VERSION %IRSSI);

use Irssi;

$VERSION = '0.01';
%IRSSI = (
  authors     => 'Jason Owen',
  contact     => 'jason.a.owen@gmail.com',
  name        => 'URL Details',
  description => 'Print details of recognized incoming links ' .
                 'and canonicalize recognized outgoing links.' .
  license     => 'GPLv3',
);

Irssi::signal_add('message public', \&UrlDetails::message);
Irssi::signal_add('send text', \&UrlDetails::send_text);

package UrlDetails;
use HTTP::Tiny;

my $tiny = HTTP::Tiny->new((
  agent => "$main::IRSSI{name}/$main::VERSION",
  timeout => 5,
));

my @url_types = (UrlDetails::YouTube::new($tiny));

sub message {
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

sub send_text {
  my ($_, $server, $window) = @_;
  return unless $window;
  my @words = ();

  foreach my $word (split) {
    foreach my $url_type (@url_types) {
      if ($url_type->contains_link($word)) {
        $server->print($window->{name}, $url_type->details($word), Irssi::MSGLEVEL_NOTICES);
        $word = $url_type->canonical_link($word);
      }
      push(@words, $word);
    }
  }
  my $line = join(" ", @words);
  Irssi::signal_continue($line, $server, $window);
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
