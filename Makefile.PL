use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'DateTime::BusinessHours',
    AUTHOR              => 'Antano Solar <solar345@gmail.com>',
    VERSION_FROM        => 'lib/DateTime/BusinessHours.pm',
    ABSTRACT_FROM       => 'lib/DateTime/BusinessHours.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'DateTime-BusinessHours-*' },
);
