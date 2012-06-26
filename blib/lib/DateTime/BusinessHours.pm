package DateTime::BusinessHours;
use DateTime;
use strict;
use warnings;
use integer;

use vars qw($VERSION);

BEGIN
{
    $VERSION = '1.01';
  }


use Class::MethodMaker
    [ scalar => [qw/ datetime1 datetime2 worktiming weekends holidayfile holidays /],
    
    ];

sub new
  {
    my $self=shift;
    my %args=@_;
    my $datetime1 = $args{datetime1} || die "datetime1 parameter required";
    my $datetime2 = $args{datetime2} || die "datetime2 parameter required";
    my $worktiming = $args{worktiming} || [9,18];
    my $weekends = $args{weekends} || [6,7];
    my $holidays = $args{holidays} || "" ;
    my $holidayfile = $args{holidayfile} || "";
    return bless {datetime1=>$datetime1,datetime2=>$datetime2,worktiming=>$worktiming,weekends=>$weekends,holidays=>$holidays,holidayfile=>$holidayfile} , $self;
    
    
  }

sub getdays
    {
      my $self = shift;
      my $datediff=$self->datetime2-$self->datetime1;
      my $days = $datediff->delta_days;
      my $noofweeks = $days/7;
      my $extradays = $days%7;
      my $startday = $self->datetime1->day_of_week;

      #exclude any day in the week marked as holiday (ex: saturday , sunday)
      $days = $days - ($noofweeks * ($#{$self->weekends}+1));  

      #this is for the extra days that dont make up 7 days , to remove holidays from them
      foreach (@{$self->weekends}) {
	if ($startday == $_) {
	  $days = $days - 1;
	  
	}
	else {
	  if ($_ >= $startday) {
	    if ($startday+$extradays >= $_) {
	      $days = $days - 1;
	      
	    }
	  }
	  else {
	    if (7-$startday+$extradays >= $_) {
	      $days = $days -1;
					       
	    }
	  }
	}
      }
      # Read company holiday's from the file 
      if ($self->holidayfile) {
	open(HF , $self->holidayfile) || warn "Predinfed holiday file not found";
	#exclude any holidays that have been marked in the companies academic year
	forHF: foreach(<HF>)
	  {
	    my ($year , $month , $day) = split('-',$_);
	    my $holidate = DateTime->new(year=>$year,month=>$month,day=>$day);
	    #check if mentioned holiday lies in defined weekend , shouldnt deduct twice
	    foreach (@{$self->weekends}) {
	      if ($holidate->day_of_week==$_) {
		last forHF 
	      }
	      if (dateinbetween($holidate)) {
		$days = $days - 1;
		
	      }
	    }


	  }
      }
      
	#added to the new release to also allow holidays as reference needs testing 
	if ($self->holidays) {
	  my $holidays = $self->holidays;
	  
	forHS: foreach(@$holidays)
	    {
	      my ($year , $month , $day) = split('-',$_);
	      my $holidate = DateTime->new(year=>$year,month=>$month,day=>$day);
	      #check if mentioned holiday lies in defined weekend , shouldnt deduct twice
	      foreach (@{$self->weekends}) {
		if ($holidate->day_of_week==$_) {
		  last forHS 
		}
		if (dateinbetween($holidate)) {
		  $days = $days - 1;
		
		}
	      }


	    }


      }      
      return $days;
      
  }          
      
      
    
sub gethours 
      {
	my $self=shift;
	my $days=$self->getdays;

	# (-2)To remove the start day and the last day as they may have different number
	#of working hours or none at all.
	$days -= 2;
	my $hoursinaday = $self->worktiming->[1]-$self->worktiming->[0];
	my $hours = $days * $hoursinaday;
	my $hoursinfirstday;
	my $hoursinlastday;
	
	# To calculate working hours in the first day.
	if ($self->datetime1->hour < $self->worktiming->[0]) {
	   $hoursinfirstday = $hoursinaday;
	}
	  elsif ($self->datetime1->hour > $self->worktiming->[1]) {
	    $hoursinfirstday = 0;
	    
	  }
	  else {
	    $hoursinfirstday = $self->worktiming->[1]-$self->datetime1->hour;
	    }
	# To calculate working hours in the last day  
	if ($self->datetime2->hour > $self->worktiming->[1]) {
	   $hoursinlastday = $hoursinaday;
	}
	
	  elsif ($self->datetime2->hour < $self->worktiming->[0]) {
	    $hoursinlastday = 0;
	    
	  }
	  else {
	    $hoursinlastday = $self->datetime2->hour-$self->worktiming->[0];
	    }
	  
	$hours = $hours + $hoursinfirstday + $hoursinlastday;
	return $hours;
	
      }
      
sub dateinbetween
	{
	my $self = shift;
	my $holidate = shift;
	#cant use >= and <= here as when it is true for  == and == condition,
	#months of the three dates  has to be checked for with similar conditions.
	#The same logic applies when checking for a date in between months 
	#and on equalty  goes down to comparision on days.An alternate method could have been 
	#converting the date to number of days from epouch and comparing them
	if ($holidate->year > $self->datetime1->year and $holidate->year <= $self->datetime2->year) {
	  return 1;
	  }
	if ($holidate->year >= $self->datetime1->year and $holidate->year < $self->datetime2->year) {
	  return 1;
	  }
	if ($holidate->year == $self->datetime1->year and $holidate->year == $self->datetime2->year) {
	  if ($holidate->month > $self->datetime1->month and $holidate->month <= $self->datetime2->month) {
	    return 1;
	     }
	  if ($holidate->month >= $self->datetime1->month and $holidate->month < $self->datetime2->month) {
	    return 1;
	    
	  }
	  if ($holidate->month == $self->datetime1->month and $holidate->month == $self->datetime2->month) {
	    if ($holidate->date >= $self->datetime1->day and $holidate->day <= $self->datetime2->day) {
	      return 1;
	    }
	  }
	}
	return 0;
	}
	
	1;

__END__


=head1 NAME

BusinessHours - An object that calculates business days and hours 

=head1 SYNOPSIS

  use BusinessHours;
  use DateTime;

  my $datetime1=DateTime->new(year=>2007,month=>10,day=>15);
  my $datetime2 = DateTime->now;

  my $testing = BusinessHours->new(datetime1=>$datetime1,
                                  datetime2=>$datetime2,
                                  worktiming=>[9,18], # 9 am to 6 om
                                  weekends=>[6,7], #saturday , sunday
                                  holidays=>["2007-10-31",2007-12-24]
                                  holidayfile=>'holidaylist' #holidaylist is a text file 
                                                             #with each date in a new line
                                                             #in the format yyyy-mm-dd  
                                 );

  print $testing->getdays."\n"; # the total business days 

  print $testing->gethours; # the total business hours


=head1 DESCRIPTION

BusinessHours a class for caculating the business hours between two DateTime objects.It can be useful in situations like escalation where an action has to happen after a certain number of business hours.

=head1 USAGE

Create an instance of the class with the two required datetime objects. 
and use the methods to get the business hours or days.

=head3 Constructors

=over 4

=item * new( ... )

This class method accepts the following parameters in the hash format.

            datetime1    =>  Starting Date 
            datetime2    =>  Ending Date
            worktimings  =>  A list reference with two values.Starting and ending hour of the day.
                             Defaults to [9,18] 
            weekends     =>  A list reference with values of the days that must be considered 
                             as non-working in a week.Defaults to [6,7] - Saturday , Sunday.
            holidays     =>  A list reference with holiday dates.
            holidayfile  =>  The name of a file from which predefined holidays can be excluded
                             from business days /hours calculation. Defaults to no file.


=head3  Methods

This class has two methods.

=over 4

=item * getdays

Returns the number of business days

=item * gethours

Returns the number of business hours.

=back

=head1 AUTHOR

Antano Solar John<solar345@gmail.com>


=head1 COPYRIGHT

Copyright (c) 2007 Antano Solar John.  All rights reserved.  This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


The full text of the license can be found in the LICENSE file included
with this module.

=cut

	
      


  
