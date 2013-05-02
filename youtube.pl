use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use HTTP::Tiny;
use Number::Format 'format_number';
use XML::Simple;

$VERSION = '0.01';
%IRSSI = (
  authors     => 'Jason Owen',
  contact     => 'jason.a.owen@gmail.com',
  name        => 'Youtube',
  description => 'Print title of incoming youtube links ' .
                 'and canonicalize outgoing links.' .
  license     => 'GPLv3',
);

sub message {
  my ($server, $_, $nick, $mask, $target) = @_;
  return unless $server;

  #$server->print($target, "server: $server, data: $data, nick: $nick, mask: $mask, target: $target", MSGLEVEL_CRAP);

  foreach my $word (split) {
    if (contains_youtube_link($word)) {
      $server->print($target, youtube_details($word), MSGLEVEL_NOTICES);
    }
  }
}

sub contains_youtube_link {
  ($_) = @_;
  return (contains_youtube_fulllink() or contains_youtube_shortlink())
}

sub contains_youtube_fulllink {
  return /youtube\.com\/watch\?.+/;
}

sub contains_youtube_shortlink {
  return /youtu\.be\/.+/;
}

sub get_video_id {
  ($_) = @_;
  if (contains_youtube_shortlink()) {
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

sub canonical_youtube_link {
  my ($word) = @_;
  my $video_id = get_video_id($word);
  my $link = "https://youtu.be/$video_id";
  my $time = get_time($word);
  if ($time) {
    $link .= "#$time";
  }
  return $link;
}

sub get_youtube_api_url {
  my ($video_id) = @_;
  return "https://gdata.youtube.com/feeds/api/videos/$video_id?v=2";
}

sub youtube_xml_title {
  my ($xml) = @_;
  return $xml->{"title"};
}

sub youtube_xml_date {
  my ($xml) = @_;
  return substr($xml->{"published"}, 0, 10);
}

sub youtube_xml_views {
  my ($xml) = @_;
  return format_number($xml->{"yt:statistics"}->{"viewCount"});
}

sub youtube_api_parse {
  my ($response) = @_;
  if ($response->{success}) {
    my $xml = XMLin($response->{content});
    return (
      youtube_xml_title($xml),
      youtube_xml_date($xml),
      youtube_xml_views($xml),
    );
  } else {
    return join(" ", "API call failed:", $response->{status}, $response->{reason});
  }
}

sub youtube_api_details {
  my ($word) = @_;
  my $video_id = get_video_id($word);
  my $api_url = get_youtube_api_url($video_id);
  my $response = HTTP::Tiny->new->get($api_url);
  return youtube_api_parse($response);
}

sub youtube_details {
  my ($word) = @_;
  return "-Youtube- " . join(" | ",
    canonical_youtube_link($word),
    youtube_api_details($word)
  );
}

Irssi::signal_add('message public', \&message);
