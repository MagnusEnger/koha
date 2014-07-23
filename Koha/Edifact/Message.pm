package Koha::Edifact::Message;

use strict;
use warnings;

use Koha::Edifact::Line;

sub new {
    my ( $class, $data_array_ref ) = @_;
    my $header       = shift @{$data_array_ref};
    my $bgm          = shift @{$data_array_ref};
    my $msg_function = $bgm->elem(2);

    my $self = {
        header                   => $header,
        bgm                      => $bgm,
        message_reference_number => $header->elem(0),
        datasegs                 => $data_array_ref,
    };

    # line_items

    bless $self, $class;
    return $self;
}

sub message_refno {
    my $self = shift;
    return $self->{message_reference_number};
}

sub function {
    my $self         = shift;
    my $msg_function = $self->{bgm}->elem(2);
    if ( $msg_function == 9 ) {
        return 'original';
    }
    elsif ( $msg_function == 7 ) {
        return 'retransmission';
    }
    return;
}

sub message_reference_number {
    my $self = shift;
    return $self->{header}->elem(0);
}

sub message_type {
    my $self = shift;
    return $self->{header}->elem( 1, 0 );
}

sub message_code {
    my $self = shift;
    return $self->{bgm}->elem( 0, 0 );
}

sub docmsg_number {
    my $self = shift;
    return $self->{bgm}->elem(1);
}

sub lineitems {
    my $self = shift;
    if ( $self->{quotation_lines} ) {
        return $self->{quotation_lines};
    }
    else {
        my $items    = [];
        my $item_arr = [];
        foreach my $seg ( @{ $self->{datasegs} } ) {
            my $tag = $seg->tag;
            if ( $tag eq 'LIN' ) {
                if ( @{$item_arr} ) {
                    push @{$items}, Koha::Edifact::Line->new($item_arr);
                }
                $item_arr = [$seg];
                next;
            }
            elsif ( $tag =~ m/^(UNS|CNT|UNT)$/sxm ) {
                if ( @{$item_arr} ) {
                    push @{$items}, Koha::Edifact::Line->new($item_arr);
                }
                last;
            }
            else {
                if ( @{$item_arr} ) {
                    push @{$item_arr}, $seg;
                }
            }
        }
        $self->{quotation_lines} = $items;
        return $items;
    }
}

1;
