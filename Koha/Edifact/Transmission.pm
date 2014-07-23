package Koha::Edifact::Transmission;

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
