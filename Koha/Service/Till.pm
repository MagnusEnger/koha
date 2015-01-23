package Koha::Service::Till;

use Modern::Perl;
use JSON;

use base 'Koha::Service';

use Koha::Database;
use Data::Dumper;

sub new {
    my ( $class ) = @_;

    return $class->SUPER::new( {
        needed_flags => { admin => 'edit_tills' },
        routes => [
            [ qr'GET /', 'read' ],
            [ qr'POST /', 'create' ],
            [ qr'PUT /(\d+)', 'update' ],
            [ qr'DELETE /(\d+)', 'delete' ],
        ]
    } );
}

sub create {
    my ( $self ) = @_;

    my $result = {};
    my $input = $self->query->param('POSTDATA');


}

sub read {
    my ( $self, $tillid ) = @_;

    my $response = {};
    my $schema = Koha::Database->new()->schema();
    my $tills_rs = $schema->resultset('CashTill')->search( { } );

    $response->{recordsTotal} = $tills_rs->count;
    $response->{recordsFiltered} = $tills_rs->count;
    while ( my $till = $tills_rs->next ) {
        push @{$response->{data}}, { $till->get_columns };
    }

    $self->output( $response, { status => '200 OK', type => 'json' } );
    return;
}

sub update {
    my ( $self, $tillid ) = @_;

    my $response = {};
    my $input = from_json($self->query->param('PUTDATA'));
    my $schema = Koha::Database->new()->schema();
    my $till = $schema->resultset('CashTill')->find( { tillid => $tillid } );

    unless ( $till ) {
        $self->output( {}, { status => '404', type => 'json' } );
        return;
    }

    $till->update( $input )->discard_changes();
    $self->output( { $till->get_columns }, { status => '200 OK', type => 'json' } );

    return;
}

sub delete {
    my ( $self, $tillid ) = @_;

}

1;
