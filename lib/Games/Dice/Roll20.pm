package Games::Dice::Roll20;
use strict;
use warnings;
use Parse::RecDescent;
use Moo;

my $grammer = q{
        startrule: dice | num
	dice: num(s?) 'd' num(s) { $return = Games::Dice::Roll20::dice($item[1]->[0],$item[3]->[0]) }
	num: /[0-9]+/ { $return = $item[1] }
};

my $parser = Parse::RecDescent->new($grammer);

sub roll {
    my ( $self, $spec ) = @_;
    return $parser->startrule($spec);
}

sub dice {
    my ( $number, $sides ) = @_;
    $number ||= 1;
    my $result;
    for ( 1 .. $number ) {
        $result += int( rand($sides) ) + 1;
    }
    return $result;
}

1;
