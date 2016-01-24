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

srand( 0.5, 0.5, 0.5, 0.5 );
roll '8d100k4', 204;

srand(0.9);
roll '4d(3+3)', 9;
srand(0.9);
roll '(2+2)d6', 9;
srand(0.9);
roll '5d6!p', 10;
srand(0.9);
roll '5d6!p>5', 10;
srand(0.9);
roll '3d6>3f1', -1;
srand(0.9);
roll '10d6<4f>5', 8;
srand(0.9);
roll '10d6<4', 9;
srand( 0.9, 0.9 );
roll '10d6>4', 2;
srand(0.9);
roll '10d6=6', 1;
srand(0.9);
roll '5d6!!', 11;
srand(0.75);
roll '5d6!!5', 10;
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
}

done_testing;
