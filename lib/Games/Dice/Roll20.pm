package Games::Dice::Roll20;
use strict;
use warnings;

#$::RD_TRACE=1;
use Parse::RecDescent;
use Moo;

## grammer stolen from https://github.com/agentzh/perl-parsing-library-benchmark

my $grammer = q{
    expr: <leftop: term add_op term>
    {
        my $list = $item[1];
        my $i    = 0;
        my $n    = @$list;
        my $sum  = 0 + $list->[ $i++ ];
        while ( $i < $n ) {
            my $op   = $list->[ $i++ ];
            my $term = $list->[ $i++ ];
            if ( $op eq '+' ) {
                $sum += $term;
            }
            else {
                $sum -= $term;
            }
        }
        $return = $sum;
    }

    add_op: /[+-]/

    term: <leftop: atom mul_op atom>
    {
        my $list = $item[1];
        my $i    = 0;
        my $n    = @$list;
        my $sum  = 0 + $list->[ $i++ ];
        while ( $i < $n ) {
            my $op   = $list->[ $i++ ];
            my $atom = $list->[ $i++ ];
            if ( $op eq '*' ) {
                $sum *= $atom;
            }
            else {
                $sum /= $atom;
            }
        }
        $return = $sum;
    }

    mul_op: /[*\/]/

    atom:
          dice
        | number
        | '(' <commit> expr ')'  { $return = $item{expr} }
        | <error?> <reject>

    number: /[-+]?\d+(?:\.\d+)?/

    dice: count 'd' sides modifiers[sides => $item{sides}](s?)
    {
        $return = Games::Dice::Roll20::Dice->new(
            amount    => $item{count}->[0],
            sides     => $item{sides},
            modifiers => { map { @{$_} } @{ $item{'modifiers(s?)'} } },
          )
    }

    modifiers:   compounding
               | penetrating
               | exploding
               | successes_and_failures
               | keep_and_drop

    keep_and_drop:   'kh' int { $return = [ 'keep_highest' => $item[2] ] }
                   | 'kl' int { $return = [ 'keep_lowest'  => $item[2] ] }
                   | 'k'  int { $return = [ 'keep_highest' => $item[2] ] }
                   | 'dh' int { $return = [ 'drop_highest' => $item[2] ] }
                   | 'dl' int { $return = [ 'drop_lowest'  => $item[2] ] }
                   | 'd'  int { $return = [ 'drop_lowest'  => $item[2] ] }

    successes_and_failures: successes failures(s?) { $return = [ successes => $item[1], failures => $item[2]->[0] ] }

    successes: compare_point

    failures: 'f' compare_point

    compounding: '!!' compare_point(s?)
    {
        $return =
          [ $item[0], $item[2]->[0] ? $item[2]->[0] : [ '=', $arg{sides} ] ]
    }

    penetrating: '!p' compare_point(s?)
    {
        $return = [
            $item[0], 1,
            'exploding', $item[2]->[0] ? $item[2]->[0] : [ '=', $arg{sides} ]
          ]
    }

    exploding: '!' compare_point(s?)
    {
        $return =
          [ $item[0], $item[2]->[0] ? $item[2]->[0] : [ '=', $arg{sides} ] ]
    }

    compare_point:   '<' int { [@item[1,2]] }
                   | '=' int { [@item[1,2]] }
                   | '>' int { [@item[1,2]] }
                   |     int { ['=',$item[1]] }

    count:   '(' expr ')' { $return = [$item[2]] }
           | int(s?)

    sides:   '(' expr ')' { $return = $item[2] }
           | int
           | 'F'

    int: /\d+/
};

my $parser = Parse::RecDescent->new($grammer);

sub eval {
    my ( $self, $spec ) = @_;
    return $parser->expr($spec);
}

package Games::Dice::Roll20::Dice;
use Moo;
use List::Util qw(sum0);
use overload
  '+'   => \&add,
  '-'   => \&minus,
  '*'   => \&mult,
  '/'   => \&div,
  '0+'  => \&to_number,
  'cmp' => \&cmp,
  ;

has sides => ( is => 'ro' );
has amount => (
    is      => 'ro',
    default => sub { 1 },
    coerce  => sub { defined $_[0] ? $_[0] : 1 }
);

has modifiers => ( is => 'ro', default => sub { {} } );

sub roll {
    my ($self) = @_;
    my $num_generator;
    if ( $self->sides eq 'F' ) {
        $num_generator = sub { int( rand 3 ) - 1 };
    }
    else {
        $num_generator = sub { int( rand( $self->sides ) ) + 1 };
    }
    my @throws;
    for ( 1 .. $self->amount ) {
        push @throws, $num_generator->();
    }

    if ( $self->modifiers->{exploding} ) {
        my ( $op, $target ) = @{ $self->modifiers->{exploding} };
        $op ||= '=';
        $target ||= $self->sides;
        my @a = @throws;
        while ( my $throw = shift @a ) {
            if ( $self->matches_cp( $throw, $op, $target ) ) {
                my $new_die = $num_generator->();
		$new_die -=1 if $self->modifiers->{penetrating};
                push @throws, $new_die;
                push @a,      $new_die;
            }
        }
    }
    if ( $self->modifiers->{compounding} ) {
        my ( $op, $target ) = @{ $self->modifiers->{compounding} };
        $op ||= '=';
        $target ||= $self->sides;
        my @a;
        while ( my $throw = shift @throws ) {
            my $new_die = $throw;
            while ( $self->matches_cp( $throw, $op, $target ) ) {
                $throw = $num_generator->();
                $new_die += $throw;
            }
            push @a, $new_die;
        }
        @throws = @a;
    }

    for my $key (qw( keep_highest keep_lowest drop_highest drop_lowest )) {
        if ( my $number = $self->modifiers->{$key} ) {
            @throws = $self->keep_and_drop( $number, $key, @throws );
            last;
        }
    }

    my $result;
    if ( $self->modifiers->{successes} ) {
        my ( $op, $target ) = @{ $self->modifiers->{successes} };
        $result = grep { $self->matches_cp( $_, $op, $target ) } @throws;
	if ( $self->modifiers->{failures} ) {
		my ( $op, $target ) = @{ $self->modifiers->{failures} };
		$result -= grep { $self->matches_cp( $_, $op, $target ) } @throws;
	}
    }
    else {
        $result = sum0 @throws;
    }

    $DB::single = 1;
    return $result;
}

sub keep_and_drop {
    my ( $self, $number, $action, @throws ) = @_;
    my ( $do, $to ) = split( '_', $action, 2 );
    my $i = 0;
    @throws =
      sort { $to eq 'highest' ? $b->[0] <=> $a->[0] : $a->[0] <=> $b->[0] }
      map { [ $_, $i++ ] } @throws;
    if ( $do eq 'drop' ) {
        splice( @throws, 0, $number );
    }
    else {
        @throws = @throws[ 0 .. $number - 1 ];
    }
    return map { $_->[0] } sort { $a->[1] <=> $b->[1] } @throws;
}

sub matches_cp {
    my ( $self, $throw, $op, $target ) = @_;
    return $throw == $target if $op eq '=';
    return $throw >= $target if $op eq '>';
    return $throw <= $target if $op eq '<';
}

sub add {
    my ( $self, $op ) = @_;
    return $self->roll + $op;
}

sub minus {
    my ( $self, $op, $swap ) = @_;
    my $result = $self->roll - $op;
    $result = -$result if $swap;
    return $result;
}

sub mult {
    my ( $self, $op ) = @_;
    return $self->roll * $op;
}

sub to_number {
    my ($self) = @_;
    return $self->roll;
}

sub cmp {
    my ( $self, $op, $swap ) = @_;
    my $result = $self->roll cmp $op;
    $result = -$result if $swap;
    return $result;
}

1;
