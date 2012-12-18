#----------------------------------------
#
# array { new Object($_) } [1 .. 2]; => [Object, Object]
#
# first [1, 2, 3];    => 1
# rest [1, 2, 3];     => [2, 3]
# left [1, 2, 3], 2;  => [1, 2]
# right [1, 2, 3], 2; => [2, 3]
#
# range 1, 10;     => [1, 2, ..., 10]
# range 10, 1;     => [10, 9, ..., 1]
# range -1, -10;   => [-1, -2, ..., -10]
# range 0, 0.1, 1; => [0, 0.1, 0.2, ..., 1.0]
#
# foldl { $_[0] . $_[1] } "", [qw/a b c/]; => "abc"
# foldr { $_[0] . $_[1] } "", [qw/a b c/]; => "cba"
# apply { $_[0] * $_[1] } [1 .. 5];        => 120
#
# zip [1, 2], [3, 4], [5, 6]; => [1, 3, 5, 2, 4, 6]
# zip_map { $_[0] . $_[1] } ["a", "b"], ["c", "d"]; => ["ac", "bd"]
#
# filter { $_ % 2 == 0 } [1 .. 5]; => [2, 4]
# filter_map { $_ % 2 == 0 && $_ + $_ } [1 .. 5]; => [4, 8]
#
#----------------------------------------

package Yoba::Functional;

use 5.010;
use strict;
use warnings;
use Carp;

use base "Exporter";
our @EXPORT    = qw/array first rest left right range foldl foldr apply zip zip_map filter filter_map/;
our @EXPORT_OK = @EXPORT;

# -> sub, [any]
# <- (any) | [any]
sub array(&$)
{
   my($function, $array) = @_;

   my @result = map { $function->($_) } @$array;

   return wantarray ? @result : \@result;
}

# -> [any]
# <- any
sub first($)
{
   return ${ $_[0] }[0];
}

# -> [any]
# <- (any) | [any]
sub rest($)
{
   my @result = @{ $_[0] }[1 .. $#{ $_[0] }];

   return wantarray ? @result : \@result;
}

# -> [any], number
# <- (any) | [any]
sub left($;$)
{
   my($array, $count) = @_;
   $count ||= 1;
   Carp::croak unless $count <= @$array;

   my @result = @$array[0 .. $count - 1];

   return wantarray ? @result : \@result;
}

# -> [any], number
# <- (any) | [any]
sub right($;$)
{
   my($array, $count) = @_;
   $count ||= 1;
   Carp::croak unless $count <= @$array;

   my @result = @$array[$#$array - $count + 1 .. $#$array];

   return wantarray ? @result : \@result;
}

# -> number, number, number
# <- (number) | [number]
sub range($$;$)
{
   my($first, $second, $last) = @_;

   my $step;
   if(defined $last)
   {
      $step = $second - $first;
   }
   else
   {
      $last = $second;
      $step = $last >= $first ? 1 : -1;
   }

   if($step == 1 && $first >= 0 && $last >= 0 && $last >= $first)
   {
      return wantarray ? ($first .. $last) : [$first .. $last];
   }

   my @result;
   for(my $i = $first; $step > 0 ? $i <= $last : $i >= $last; $i += $step)
   {
      push @result, $i;
   }

   return wantarray ? @result : \@result;
}

# -> sub, any, [any]
# <- any
sub foldl(&$$)
{
   my($function, $result, $array) = @_;
   $result = $function->($result, $_) for @$array;
   return $result;
}

# -> sub, any, [any]
# <- any
sub foldr(&$$)
{
   my($function, $result, $array) = @_;
   $result = $function->($_, $result) for reverse @$array;
   return $result;
}

# -> sub, [any]
# <- any
sub apply(&$)
{
   my($function, $array) = @_;
   my $result = first $array;
   $result = $function->($result, $_) for rest $array;
   return $result;
}

# -> [any], [any], ...
# <- (any) | [any]
sub zip(@)
{
   my @arrays = @_;

   if(@arrays == 1)
   {
      return wantarray ? @{ $arrays[0] } : [@{ $arrays[0] }];
   }

   my $size = @{ $arrays[0] };
   for(@arrays)
   {
      Carp::croak unless @$_ == $size;
   }

   my @result;
   for my $i (0 .. $size - 1)
   {
      push @result, $_->[$i] for @arrays;
   }

   return wantarray ? @result : \@result;
}

# -> sub, [any], [any], ...
# <- (any) | [any]
sub zip_map(&@)
{
   my($function, @arrays) = @_;
   my $array = zip @arrays;
   my $arrays_count = @arrays;

   my @result;
   push @result, $function->(splice @$array, 0, $arrays_count) while @$array;

   return wantarray ? @result : \@result;
}

# -> sub, [any]
# <- (any) | [any]
sub filter(&$)
{
   my($function, $array) = @_;

   my @result = grep { $function->($_) } @$array;

   return wantarray ? @result : \@result;
}

# -> sub, [any]
# <- (any) | [any]
sub filter_map(&$)
{
   my($function, $array) = @_;

   my @result = grep { $_ } map { $function->($_) } @$array;

   return wantarray ? @result : \@result;
}

2;
