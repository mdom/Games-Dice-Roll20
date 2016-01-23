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
            my $i = 0;
            my $n = @$list;
            my $sum = 0 + $list->[$i++];
            while ($i < $n) {
                my $op = $list->[$i++];
                my $term = $list->[$i++];
                if ($op eq '+') {
                    $sum += $term;
                } else {
                    $sum -= $term;
                }
            }
            $return = $sum;
        }
    add_op: /[+-]/
    term: <leftop: atom mul_op atom>
        {
            my $list = $item[1];
            my $i = 0;
            my $n = @$list;
            my $sum = 0 + $list->[$i++];
            while ($i < $n) {
                my $op = $list->[$i++];
                my $atom = $list->[$i++];
                if ($op eq '*') {
                    $sum *= $atom;
                } else {
                    $sum /= $atom;
                }
            }
            $return = $sum;
        }
    mul_op: /[*\/]/
    atom:
          dice
	| number
        | '(' <commit> expr ')'  { $return = $item{expr}; }
        | <error?> <reject>
    number: /[-+]?\d+(?:\.\d+)?/
    dice: count 'd' sides modifiers[sides => $item{sides}](s?)
        {
                $return = Games::Dice::Roll20::Dice->new(
                    amount    => $item{count}->[0],
                    sides     => $item{sides},
                    modifiers => {
                        map { $_->[0] => $_->[1] } @{ $item{'modifiers(s?)'} }
                    },
                  )
              }
    modifiers: exploding
    exploding: '!' compare_point(s?)
	    {
		$return =
		  [ $item[0], $item[2]->[0] ? $item[2]->[0] : [ '=', $arg{sides} ] ]
	    }
    compare_point: '<' int { [@item[1,2]] }
                 | '=' int { [@item[1,2]] }
		 | '>' int { [@item[1,2]] }
		 |     int { ['=',$item[1]] }
    count: int(s?)
    sides: int | 'F'
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
            if (   $op eq '=' && $throw == $target
                or $op eq '>' && $throw >= $target
                or $op eq '<' && $throw <= $target )
            {
                my $new_die = $num_generator->();
                push @throws, $new_die;
                push @a,      $new_die;
            }
        }
    }

    my $result = sum0 @throws;
    return $result;
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
