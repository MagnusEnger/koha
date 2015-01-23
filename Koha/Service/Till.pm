package Koha::Service::Till;

use Modern::Perl;

use base 'Koha::Service';

use Koha::Database;

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
    warn "hit get till resource";

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
    my ( $self ) = @_;

    my $input = $self->query->param('POSTDATA');
    my $result = {};
}

sub delete {
    my ( $self, $tillid ) = @_;

}

1;
