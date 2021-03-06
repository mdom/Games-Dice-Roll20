# This file was automatically generated by Dist::Zilla::Plugin::MakeMaker v5.035.
use strict;
use warnings;



use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Simulate dice rolls with Roll20's syntax",
  "AUTHOR" => "Mario Domgoergen C<< <mario\@domgoergen.com> >>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Games-Dice-Roll20",
  "EXE_FILES" => [
    "bin/roll20"
  ],
  "LICENSE" => "gpl",
  "NAME" => "Games::Dice::Roll20",
  "PREREQ_PM" => {
    "List::Util" => 0,
    "Moo" => 0,
    "POSIX" => 0,
    "Parse::RecDescent" => 0,
    "overload" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Test::More" => 0
  },
  "VERSION" => "0.03",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "ExtUtils::MakeMaker" => 0,
  "List::Util" => 0,
  "Moo" => 0,
  "POSIX" => 0,
  "Parse::RecDescent" => 0,
  "Test::More" => 0,
  "overload" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
