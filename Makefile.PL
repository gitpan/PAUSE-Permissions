
use strict;
use warnings;



use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "interface to PAUSE's module permissions file (06perms.txt)",
  "AUTHOR" => "Neil Bowers <neil\@bowers.com>",
  "BUILD_REQUIRES" => {},
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => "6.30"
  },
  "DISTNAME" => "PAUSE-Permissions",
  "EXE_FILES" => [],
  "LICENSE" => "perl",
  "NAME" => "PAUSE::Permissions",
  "PREREQ_PM" => {
    "File::HomeDir" => 0,
    "File::Spec::Functions" => 0,
    "HTTP::Tiny" => 0,
    "Moo" => 0,
    "autodie" => 0,
    "feature" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "File::Slurp" => 0,
    "Test::More" => "0.88"
  },
  "VERSION" => "0.06",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "File::HomeDir" => 0,
  "File::Slurp" => 0,
  "File::Spec::Functions" => 0,
  "HTTP::Tiny" => 0,
  "Moo" => 0,
  "Test::More" => "0.88",
  "autodie" => 0,
  "feature" => 0,
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



