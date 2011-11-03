package C4::RoutingSlip::Copyright;
use strict;
use warnings;
use 5.10.1;

sub new {
    my $class = shift;

    my $self = _init(@_);
    bless $self, $class;
    if ( $self->{id} ) {
        $self->get( $self->{id} );
    }
    return $self;
}

sub txt {
    my $self = shift;
    return $self->{txt};
}

sub code {
    my $self = shift;
    return $self->{code};
}

sub id {
    my $self = shift;
    return $self->{id};
}

sub get {
    my $self = shift;
    $self->{id} = shift;
    if ( $self->{test} == 1 ) {
        $self->{txt}  = 'Test text';
        $self->{code} = 'TEST';
    }
    else {
        my $dbh      = C4::Context->dbh;
        my $hash_ref = $dbh->selectrow_hashref(
            'SELECT txt, code from rlcopyright where id = ?',
            {}, $self->{id} );
        $self->{txt}  = $hash_ref->{txt};
        $self->{code} = $hash_ref->{code};
    }
    return;
}

sub get_all {
    my $class     = shift;
    my %parm      = @_;
    my $ret_array = [];
    if ( $parm{test} == 1 ) {
        for my $i ( 1 .. 3 ) {
            push @{$ret_array}, $class->new( test => 1, id => $i );
        }
    }
    else {
        my $dbh = C4::Context->dbh;
        my $ids = $dbh->selectall_arrayref( 'SELECT id from rlcopyright',
            { Slice => {} } );
        foreach my $id ( @{$ids} ) {
            push @{$ret_array}, $class->new( id => $id->{id} );
        }
    }
    return $ret_array;
}

sub _init {
    my %parms = @_;
    my $self  = {};
    if ( exists $parms{test} ) {
        $self->{test} = 1;
    }
    else {
        $self->{test} = 0;
    }
    if ( $parms{id} ) {
        $self->{id} = $parms{id};
    }

    return $self;
}

DESTROY {
    my $self = shift;
    $self = undef;
}
1;
