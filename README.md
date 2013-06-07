irssi-urldetails
================

Never be rickrolled again.

An irssi script to show details of supported links. It can also clean up links you type as you send them, so that `www.youtube.com/watch?v=dQw4w9WgXcQ&feature=youtu.be` becomes `https://youtu.be/dQw4w9WgXcQ`.

Preview
-------

    < strawman> can I see some samples of this plugin?
    <@jasonaowen> sure! on the next line I'll post three links
    -is.gd- http://is.gd/example -> http://www.example.com
    -YouTube- https://youtu.be/dQw4w9WgXcQ | Rick Astley - Never Gonna Give You Up | 3m33s | 2009-10-25 | 64,091,243
    -Vimeo- https://vimeo.com/2 | Good morning, universe | 29s | 2005-02-16 | 606,856
    <@jasonaowen> is.gd/example www.youtube.com/watch?v=dQw4w9WgXcQ&feature=youtu.be http://vimeo.com/2
    <@jasonaowen> note that they appear in the client before my message

Requirements
------------

### Runtime
* HTTP::Tiny
* Number::Format
* Time::Duration
* XML::Simple

### Test
* File::Slurp
* Test::MockObject
* Test::More

### In debian-based distributions
`sudo aptitude install libhttp-tiny-perl libnumber-format-perl libtime-duration-perl libxml-simple-perl libfile-slurp-perl libtest-mockobject-perl`

Installation
------------

Drop urldetails.pl into ~/.irssi/scripts, optionally create a symlink to it in ~/.irssi/scripts/autorun, and `/script load urldetails`.

Settings
--------

URL canonicalization can be turned on and off for each service. For example, `/set canonicalize_youtube off` will prevent outgoing YouTube links from being reformatted into `https://youtu.be/video_id`. `/set canonicalize` will show you the list of services and what each is set to. Canonicalization defaults to `ON`.
