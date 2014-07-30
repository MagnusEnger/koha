package Koha::Edifact::Message;

# Copyright 2014 PTFS-Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

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
__END__

=head1 NAME
   Koha::Edifact::Message

=head1 SYNOPSIS


=head1 DESCRIPTION

Class modelling an Edifact Message for parsing

=head1 BUGS


=head1 SUBROUTINES

=head2 new

=head2 message_refno

=head1 AUTHOR

   Colin Campbell <colin.campbell@ptfs-europe.com>


=head1 COPYRIGHT

   Copyright 2014, PTFS-Europe Ltd
   This program is free software, You may redistribute it under
   under the terms of the GNU General Public License


=cut
