use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Mojo::Ping',
  VERSION_FROM => 'lib/Mojo/Ping.pm',
  AUTHOR       => 'Andre Parker <andreparker@gmail.com>',
  PREREQ_PM    => {'Mojolicious' => '6.61'},
  test         => {TESTS => 't/*.t'}
);
