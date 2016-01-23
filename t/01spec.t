use strict;
use warnings;
use Test::MockRandom 'Games::Dice::Roll20::Dice';
use Games::Dice::Roll20;
use Test::More;

my $dice = Games::Dice::Roll20->new();

sub roll {
    my ( $spec, $result, $desc ) = @_;
    is( $dice->eval($spec), $result, $desc || "$spec -> $result" );
}

srand(0.9);
roll '3d6!>5', 9;
srand( 0.9, 0.9 );
roll '2d6!',        14;
roll '2d6',         2;
roll 'd6+1',        2;
roll '(2+2)',       4;
roll '(2+2)*2',     8;
roll '2*2+2',       6;
roll '((2+2)*2)+2', 10;
roll 'd6',          1;
roll '12d12',       12;
roll '2dF',         -2;
roll '0',           0;
roll '5+3',         8;
roll '0d1',         0;
roll 'd1',          1;
roll 'd6+d6',       2;
roll 'd6+d6+d6',    3;

TODO: {
    local $TODO = 'Not implemented yet';
    roll '[[5+3]]', 8;

    roll '(1+1)d6',   2;
    roll '1d(3+3)',   2;
    roll '3d6>3',     0;
    roll '10d6<4',    0;
    roll '3d6>3f1',   0;
    roll '10d6<4f>5', 0;
    roll '5d6!!',     0;
    roll '5d6!!5',    0;
    roll '5d6!p',     0;
    roll '5d6!p>5',   0;
}

done_testing;
