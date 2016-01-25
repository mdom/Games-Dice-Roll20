package Games::Dice::Roll20;
use strict;
use warnings;

#$::RD_TRACE=1;
use Moo;
use Parse::RecDescent;
use Games::Dice::Roll20::Dice;

## grammer stolen from https://github.com/agentzh/perl-parsing-library-benchmark

my $grammer = q{
    expr: <leftop: term add_op term>
    {
        $return = Games::Dice::Roll20::_reduce_list( @{ $item[1] } )
    }

    add_op: /[+-]/

    term: <leftop: atom mul_op atom>
    {
        $return = Games::Dice::Roll20::_reduce_list( @{ $item[1] } )
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
               | rerolling(s?)
                 {
                    $return =
                      @{ $item[1] }
                      ? [ 'rerolling', [ map { $_->[0] } @{ $item[1] } ] ]
                      : undef;
                 }

    rerolling: 'r' ('o')(?) compare_point(s?)
    {
        $return =
          [ $item[3]->[0] ? $item[3]->[0] : [ '=', 1 ] ];
        push @{ $return->[0] }, $item[2]->[0];
    }

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

sub roll {
    my ( $self, $spec ) = @_;
    return $parser->expr($spec);
}

sub _reduce_list {
    my (@list) = @_;
    my $sum = 0 + shift(@list);
    while (@list) {
        my $op   = shift @list;
        my $term = shift @list;
        if ( $op eq '+' ) { $sum += $term; }
        elsif ( $op eq '-' ) { $sum -= $term }
        elsif ( $op eq '*' ) { $sum *= $term }
        elsif ( $op eq '/' ) { $sum /= $term }
    }
    return $sum;
}

1;
