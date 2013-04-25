use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
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
  my ($server, $message, $nick, $mask, $target) = @_;
  return unless $server;

  #$server->print($target, "server: $server, data: $data, nick: $nick, mask: $mask, target: $target", MSGLEVEL_CRAP);

  if (contains_youtube_link($message)) {
    my $video_id = get_video_id($message);
    $server->print($target, youtube_details($video_id), MSGLEVEL_CRAP);
  }
}

sub contains_youtube_link {
  my ($message) = @_;
  return (contains_youtube_fulllink($message) or contains_youtube_shortlink($message))
}

sub contains_youtube_fulllink {
  ($_) = @_;
  return /youtube\.com\/watch\?.+/;
}

sub contains_youtube_shortlink {
  ($_) = @_;
  return /youtu\.be\/.+/;
}

sub get_video_id {
  my ($message) = @_;
  if (contains_youtube_shortlink($message)) {
    return get_video_id_from_shortlink($message);
  } else {
    return get_video_id_from_fulllink($message);
  }
}

sub get_video_id_from_shortlink {
  ($_) = @_;
  /youtu\.be\/([A-Za-z0-9_-]{11})/;
  return $1;
}

sub get_video_id_from_fulllink {
  ($_) = @_;
  /v=([A-Za-z0-9_-]{11})/;
  return $1;
}

sub youtube_details {
  my ($video_id) = @_;
  return "https://youtu.be/$video_id Youtube link detected!";
}

Irssi::signal_add('message public', \&message);
