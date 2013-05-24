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
sub message {
  my ($server, $_, $nick, $mask, $target) = @_;
  return unless $server;

  foreach my $word (split) {
    if (UrlDetails::YouTube::contains_link($word)) {
      $server->print($target, UrlDetails::YouTube::details($word), Irssi::MSGLEVEL_NOTICES);
    }
  }
}

sub send_text {
  my ($_, $server, $window) = @_;
  return unless $window;
  my @words = ();

  foreach my $word (split) {
    if (UrlDetails::YouTube::contains_link($word)) {
      $server->print($window->{name}, UrlDetails::YouTube::details($word), Irssi::MSGLEVEL_NOTICES);
      $word = UrlDetails::YouTube::canonical_link($word);
    }
    push(@words, $word);
  }
  my $line = join(" ", @words);
  Irssi::signal_continue($line, $server, $window);
}

package UrlDetails::YouTube;
use HTTP::Tiny;
use Number::Format 'format_number';
use XML::Simple;

my $tiny = HTTP::Tiny->new((
  agent => "$main::IRSSI{name}/$main::VERSION",
  timeout => 5,
));

sub contains_link {
  ($_) = @_;
  return (contains_fulllink() or contains_shortlink())
}

sub contains_fulllink {
  return /^(?:https?:\/\/)?(?:www\.)?youtube\.com\/watch\?.+/;
}

sub contains_shortlink {
  return /^(?:https?:\/\/)?youtu\.be\/.+/;
}

sub get_video_id {
  ($_) = @_;
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
  my ($_) = @_;
  /(t=[0-9smh]+)/;
  return $1;
}

sub canonical_link {
  my ($word) = @_;
  my $video_id = get_video_id($word);
  my $link = "https://youtu.be/$video_id";
  my $time = get_time($word);
  if ($time) {
    $link .= "#$time";
  }
  return $link;
}

sub get_api_url {
  my ($video_id) = @_;
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
  my ($response) = @_;
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
  my ($word) = @_;
  my $video_id = get_video_id($word);
  my $api_url = get_api_url($video_id);
  my $response = $tiny->get($api_url);
  return api_parse($response);
}

sub details {
  my ($word) = @_;
  return "-YouTube- " . join(" | ",
    canonical_link($word),
    api_details($word)
  );
}
