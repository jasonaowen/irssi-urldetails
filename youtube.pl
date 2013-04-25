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
  my ($server, $data, $nick, $mask, $target) = @_;
  return unless $server;

  #$server->print($target, "server: $server, data: $data, nick: $nick, mask: $mask, target: $target", MSGLEVEL_CRAP);

  if (contains_youtube_link($data)) {
    my $video_link = get_video_link($data);
    my $video_id = get_video_id($video_link);
    $server->print($target, youtube_details($video_id), MSGLEVEL_CRAP);
  }
}

sub contains_youtube_link {
  # example: http://www.youtube.com/watch?v=x-k0Ehx46YQ&feature=youtu.be
  ($_) = @_;
  if (/youtube\.com\/watch\?.+/ or /youtu\.be\/.+/) {
    return 1;
  }
}

sub get_video_link {
  return 0;
}

sub get_video_id {
  return 0;
}

sub youtube_details {
  return "Youtube link detected!";
}

Irssi::signal_add('message public', \&message);
