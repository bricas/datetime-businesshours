package DateTime::BusinessHours;
use strict;
use warnings;

use DateTime;
use integer;

use Class::MethodMaker [
    scalar => [
        qw( datetime1 datetime2 worktiming weekends holidayfile holidays )
    ],
];

our $VERSION = '1.01';

sub new {
    my ( $class, %args ) = @_;

    die 'datetime1 parameter required' if !$args{ datetime1 };
    die 'datetime2 parameter required' if !$args{ datetime2 };

    $args{ worktiming } ||= [ 9, 18 ];
    $args{ weekends }   ||= [ 6, 7 ];

    return bless \%args, $class;
}

sub getdays {
    my $self       = shift;
    my $start_date = $self->datetime1;
    my $end_date   = $self->datetime2;
    ( $start_date, $end_date ) = ( $end_date, $start_date )
        if $start_date > $end_date;

    my $days = $end_date->delta_days( $start_date )->in_units( 'days' );

    my $noofweeks = $days / 7;
    my $extradays = $days % 7;
    my $startday  = $start_date->day_of_week;

    #exclude any day in the week marked as holiday (ex: saturday , sunday)
    $days = $days - ( $noofweeks * ( $#{ $self->weekends } + 1 ) );

#this is for the extra days that dont make up 7 days , to remove holidays from them
    foreach ( @{ $self->weekends } ) {
        if ( $startday == $_ ) {
            $days = $days - 1;

        }
        else {
            if ( $_ >= $startday ) {
                if ( $startday + $extradays >= $_ ) {
                    $days = $days - 1;

                }
            }
            else {
                if ( 7 - $startday + $extradays >= $_ ) {
                    $days = $days - 1;

                }
            }
        }
    }

    # Read company holiday's from the file
    if ( $self->holidayfile ) {
        open( HF, $self->holidayfile )
            || warn "Predinfed holiday file not found";

    #exclude any holidays that have been marked in the companies academic year
    forHF: foreach ( <HF> ) {
            my ( $year, $month, $day ) = split( '-', $_ );
            my $holidate = DateTime->new(
                year  => $year,
                month => $month,
                day   => $day
            );

   #check if mentioned holiday lies in defined weekend , shouldnt deduct twice
            foreach ( @{ $self->weekends } ) {
                if ( $holidate->day_of_week == $_ ) {
                    last forHF;
                }
                if ( dateinbetween( $holidate ) ) {
                    $days = $days - 1;

                }
            }

        }
    }

   #added to the new release to also allow holidays as reference needs testing
    if ( $self->holidays ) {
        my $holidays = $self->holidays;

    forHS: foreach ( @$holidays ) {
            my ( $year, $month, $day ) = split( '-', $_ );
            my $holidate = DateTime->new(
                year  => $year,
                month => $month,
                day   => $day
            );

   #check if mentioned holiday lies in defined weekend , shouldnt deduct twice
            foreach ( @{ $self->weekends } ) {
                if ( $holidate->day_of_week == $_ ) {
                    last forHS;
                }
                if ( dateinbetween( $holidate ) ) {
                    $days = $days - 1;

                }
            }

        }

    }
    return $days;

}

sub gethours {
    my $self = shift;
    my $days = $self->getdays;

# (-2)To remove the start day and the last day as they may have different number
#of working hours or none at all.
    $days -= 2;
    my $hoursinaday = $self->worktiming->[ 1 ] - $self->worktiming->[ 0 ];
    my $hours       = $days * $hoursinaday;
    my $hoursinfirstday;
    my $hoursinlastday;

    # To calculate working hours in the first day.
    if ( $self->datetime1->hour < $self->worktiming->[ 0 ] ) {
        $hoursinfirstday = $hoursinaday;
    }
    elsif ( $self->datetime1->hour > $self->worktiming->[ 1 ] ) {
        $hoursinfirstday = 0;

    }
    else {
        $hoursinfirstday = $self->worktiming->[ 1 ] - $self->datetime1->hour;
    }

    # To calculate working hours in the last day
    if ( $self->datetime2->hour > $self->worktiming->[ 1 ] ) {
        $hoursinlastday = $hoursinaday;
    }

    elsif ( $self->datetime2->hour < $self->worktiming->[ 0 ] ) {
        $hoursinlastday = 0;

    }
    else {
        $hoursinlastday = $self->datetime2->hour - $self->worktiming->[ 0 ];
    }

    $hours = $hours + $hoursinfirstday + $hoursinlastday;
    return $hours;

}

sub dateinbetween {
    my $self     = shift;
    my $holidate = shift;

#cant use >= and <= here as when it is true for  == and == condition,
#months of the three dates  has to be checked for with similar conditions.
#The same logic applies when checking for a date in between months
#and on equalty  goes down to comparision on days.An alternate method could have been
#converting the date to number of days from epouch and comparing them
    if (    $holidate->year > $self->datetime1->year
        and $holidate->year <= $self->datetime2->year )
    {
        return 1;
    }
    if (    $holidate->year >= $self->datetime1->year
        and $holidate->year < $self->datetime2->year )
    {
        return 1;
    }
    if (    $holidate->year == $self->datetime1->year
        and $holidate->year == $self->datetime2->year )
    {
        if (    $holidate->month > $self->datetime1->month
            and $holidate->month <= $self->datetime2->month )
        {
            return 1;
        }
        if (    $holidate->month >= $self->datetime1->month
            and $holidate->month < $self->datetime2->month )
        {
            return 1;

        }
        if (    $holidate->month == $self->datetime1->month
            and $holidate->month == $self->datetime2->month )
        {
            if (    $holidate->date >= $self->datetime1->day
                and $holidate->day <= $self->datetime2->day )
            {
                return 1;
            }
        }
    }
    return 0;
}

1;

__END__

=head1 NAME

DateTime::BusinessHours - An object that calculates business days and hours 

=head1 SYNOPSIS

    my $d1 = DateTime->new( year => 2007, month => 10, day => 15 );
    my $d2 = DateTime->now;

    my $test = DateTime:::BusinessHours->new(
        datetime1 => $d1,
        datetime2 => $d2,
        worktiming => [ 9, 18 ], # 9am to 6pm
        weekends => [ 6, 7 ], # Saturday and Sunday
        holidays => [ '2007-10-31', '2007-12-24' ],
        holidayfile => 'holidays.txt'
        # holidayfile is a text file with each date in a new line
        # in the format yyyy-mm-dd  
   );

   print $test->getdays, "\n"; # the total business days 
   print $test->gethours, "\n"; # the total business hours

=head1 DESCRIPTION

BusinessHours a class for caculating the business hours between two DateTime 
objects. It can be useful in situations like escalation where an action has to 
happen after a certain number of business hours.

=head1 METHODS

=head2 new( %args )

This class method accepts the following arguments as parameters:

=over 4

=item * datetime1 - Starting Date 

=item * datetime2 - Ending Date

=item * worktiming - An array reference with two values: starting and ending hour of the day. Defaults to [9,18]

=item * weekends - An array reference with values of the days that must be considered as non-working in a week.Defaults to [6,7] (Saturday & Sunday)

=item * holidays - An array reference with holiday dates

=item * holidayfile - The name of a file from which predefined holidays can be excluded from business days /hours calculation. Defaults to no file.

=back

=head2 getdays( )

Returns the number of business days

=head2 gethours( )

Returns the number of business hours.

=head2 dateinbetween( $date )

Returns 1 if C<$date> is between the two dates supplied to the constructor.

=head1 INSTALLATION

To install this module, run the following commands:

	perl Makefile.PL
	make
	make test
	make install

=head1 SUPPORT AND DOCUMENTATION

After installing, you can find documentation for this module with the
perldoc command.

    perldoc DateTime::BusinessHours

You can also look for information at:

    RT, CPAN's request tracker
        http://rt.cpan.org/NoAuth/Bugs.html?Dist=DateTime-BusinessHours

    AnnoCPAN, Annotated CPAN documentation
        http://annocpan.org/dist/DateTime-BusinessHours

    CPAN Ratings
        http://cpanratings.perl.org/d/DateTime-BusinessHours

    Search CPAN
        http://search.cpan.org/dist/DateTime-BusinessHours

=head1 AUTHOR

Antano Solar John <solar345@gmail.com>

=head1 COPYRIGHT

Copyright (c) 2007 Antano Solar John.  All rights reserved.  This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included
with this module.

=cut

