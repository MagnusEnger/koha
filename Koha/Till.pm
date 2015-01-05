package Koha::Till;
use strict;
use warnings;
use Koha::Database;

sub new {
    my ( $class, @params ) = @_;

    # TBD :: based on passed parameters select a specific till

    my $schema = Koha::Database->new()->schema();
    my $tills_rs =
      $schema->resultset('CashTill')->search( { description => 'DEFAULT' } );

    my $self = {
        schema  => $schema,
        till_id => $tills_rs->[0]->tillid,
    };

    bless $self, $class;
    return $self;
}

sub payin {
    my ( $self, $amt, $code, $type ) = @_;

    # IN code will be pos
    # OUT code should be neg
    # EVENT is 0
    my $new_transaction =
      $self->{schema}->resultset('CashTransaction')->create(
        {
            amt         => $amt,
            till        => $self->{till_id},
            tcode       => $code,
            paymenttype => $type,
        }
      );
    return;
}

sub payout {
    my ( $self, $amt, $code ) = @_;
    my $new_transaction =
      $self->{schema}->resultset('CashTransaction')->create(
        {
            amt   => $amt,
            till  => $self->{till_id},
            tcode => $code,
        }
      );

    return;
}

sub ctltrans {
    my ( $self, $code ) = @_;
    my $new_transaction =
      $self->{schema}->resultset('CashTransaction')->create(
        {
            amt   => undef,
            till  => $self->{till_id},
            tcode => $code,
        }
      );
    return;
}

1;
