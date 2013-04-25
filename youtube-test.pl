#!/usr/bin/perl
use strict;
use Test::SimpleUnit qw{:functions};
Test::SimpleUnit::AutoskipFailedSetup( 1 );

sub Irssi::signal_add { return 1; }

my $RequireWasOkay = 0;

my %links = (
  'short link with protocol' => 'http://youtu.be/VjQMpBb1gps',
  'short link without protocol' => 'youtu.be/VjQMpBb1gps',
  'full link with protocol' => 'http://www.youtube.com/watch?v=VjQMpBb1gps',
  'full link without protocol' => 'www.youtube.com/watch?v=VjQMpBb1gps',
  'full link without www' => 'youtube.com/watch?v=VjQMpBb1gps',
  'full link with feature parameter' => 'www.youtube.com/watch?v=VjQMpBb1gps',
);

sub generate_contains_test {
  my ($name, $url) = @_;
  return {
    name => "contains_youtube_link finds $name",
    test => sub {
        assert contains_youtube_link($url), "Failed to detect link";
    },
  },
}

sub generate_contains_tests {
  my (%links) = @_;
  my @tests = ();

  while (my($k, $v) = each %links) {
    push(@tests, generate_contains_test($k, $v));
  }
  return @tests;
}

my @tests = (
  # Require the module
  {
    name => 'require',
    test => sub {
      # Make sure we can load the module to be tested.
      assertNoException { require "youtube.pl" };

      # Set the flag to let the setup function know the module loaded okay
      $RequireWasOkay = 1;
    },
  },
  # Setup function (this will be run before any tests which follow)
  #{
  #  name => 'setup',
  #  test => sub {
      # If the previous test didn't finish, it's untestable, so just skip the
      # rest of the tests
  #    skipAll "Module failed to load" unless $RequireWasOkay;
  #    $Instance = new MyClass;
  #  },
  #},

  # Teardown function (this will be run after any tests which follow)
  #{
  #  name => 'teardown',
  #  test => sub {
  #    undef $Instance;
  #  },
  #},

  generate_contains_tests(%links),
  {
    name => 'contains_youtube_link does not catch full link without video ID',
    test => sub {
        assert !contains_youtube_link('http://www.youtube.com/'), "Improperly detected link";
    },
  },
  {
    name => 'contains_youtube_link does not catch short link without video ID',
    test => sub {
        assert !contains_youtube_link('http://youtu.be/'), "Improperly detected link";
    },
  },
);
runTests( @tests );

