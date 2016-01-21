package Games::Dice::Roll20;
use strict;
use warnings;

#$::RD_TRACE=1;
use Parse::RecDescent;
use Moo;

my $grammer = q{
	startrule: mult | div | add | sub | op
	add:  op '+' op { $return = $item[1] + $item[3] }
	sub:  op '-' op { $return = $item[1] - $item[3] }
	mult: op '*' op { $return = $item[1] * $item[3] }
	div:  op '/' op { $return = $item[1] / $item[3] }
	op: dice | num
	dice: count 'd' sides
	      {
		$return = Games::Dice::Roll20::Dice->new(
			amount => $item{count}->[0],
			sides  => $item{sides},
		)
              }
	count: num(s?)
	sides: num | 'F'
	num: /[0-9]+/
};

my $parser = Parse::RecDescent->new($grammer);

sub eval {
    my ( $self, $spec ) = @_;
    return $parser->startrule($spec);
}

package Games::Dice::Roll20::Dice;
use Moo;
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

sub roll {
    my ($self) = @_;
    my $result = 0;
    my $num_generator;
    if ( $self->sides eq 'F' ) {
        $num_generator = sub { int( rand 3 ) - 1 };
    }
    else {
        $num_generator = sub { int( rand( $self->sides ) ) + 1 };
    }
    for ( 1 .. $self->amount ) {
        $result += $num_generator->();
    }
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
