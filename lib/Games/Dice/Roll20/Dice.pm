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
                $new_die -= 1 if $self->modifiers->{penetrating};
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

    if ( $self->modifiers->{rerolling} ) {
        for my $cp ( @{ $self->modifiers->{rerolling} } ) {
            my @new_throws;
            my ( $op, $target, $once ) = @$cp;
            for my $throw (@throws) {
                if ( $self->matches_cp( $throw, $op, $target ) ) {
                    $throw = $num_generator->();
                    redo unless $once;
                }
                push @new_throws, $throw;
            }
            @throws = @new_throws;
        }
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

# TODO div is missing

1;
