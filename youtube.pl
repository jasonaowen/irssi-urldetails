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
  my ($server, $_, $nick, $mask, $target) = @_;
  return unless $server;

  #$server->print($target, "server: $server, data: $data, nick: $nick, mask: $mask, target: $target", MSGLEVEL_CRAP);

  foreach my $word (split) {
    if (contains_youtube_link($word)) {
      my $video_id = get_video_id($word);
      $server->print($target, youtube_details($video_id), MSGLEVEL_CRAP);
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

sub youtube_details {
  my ($video_id) = @_;
  return "https://youtu.be/$video_id Youtube link detected!";
}

Irssi::signal_add('message public', \&message);
