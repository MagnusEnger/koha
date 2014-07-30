package Koha::Edifact::Transmission;

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

use Koha::Edifact;
use Koha::Edifact::Message;

sub new {
    my ( $class, $transmission ) = @_;

    my $edi = Koha::Edifact->new( { transmission => $transmission } );

    my $self = {
        control_reference =>
          $edi->interchange_header('interchange_control_reference'),
        supplier_id  => $edi->interchange_header('sender'),
        recipient_id => $edi->interchange_header('recipient'),
        appref       => $edi->interchange_header('application_reference'),
        msg_count    => $edi->interchange_trailer('interchange_control_count'),
    };
    if ( !$self->{appref} ) {
        $self->{appref} = 'MIXED';
    }

    $self->{datetime} = join q{:}, @{ $edi->interchange_header('datetime') };

    my $msg_arr = $edi->message_array();
    $self->{msg_arr} = map { Koha::Edifact::Message->new($_) } @{$msg_arr};

    bless $self, $class;
    return $self;
}

sub control_reference {
    my $self = shift;
    return $self->{control_reference};
}

sub supplier_id {
    my $self = shift;
    return $self->{supplier_id};
}

sub recipient_id {
    my $self = shift;
    return $self->{recipient_id};
}

sub preparation_datetime {
    my $self = shift;
    return $self->{datetime};
}

sub application_reference {
    my $self = shift;
    return $self->{appref};
}

sub num_messages {
    my $self = shift;
    return $self->{msg_count};
}

sub messages {
    my $self = shift;
    return $self->{message_array};
}
1;
__END__

=head1 NAME
   Koha::Edifact::Transmission

=head1 SYNOPSIS


=head1 DESCRIPTION

This wraps the Koha::Edifact routines with a cleaner interface


=head1 BUGS


=head1 SUBROUTINES

=head2 rtn

=head1 AUTHOR

   Colin Campbell <colin.campbell@ptfs-europe.com>


=head1 COPYRIGHT

   Copyright 2014, PTFS-Europe Ltd
   This program is free software, You may redistribute it under
   under the terms of the GNU General Public License


=cut
