package Koha::Objects;

# Copyright ByWater Solutions 2014
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Carp;

use Koha::Database;

our $type;

=head1 NAME

Koha::Objects - Koha Object set base class

=head1 SYNOPSIS

    use Koha::Objects;
    my @objects = Koha::Objects->search({ borrowernumber => $borrowernumber});

=head1 DESCRIPTION

This class must be subclassed.

=head1 API

=head2 Class Methods

=cut

=head3 Koha::Objects->new();

my $object = Koha::Object->new();

=cut

sub new {
    my ($class) = shift;
    my $self = {};

    bless( $self, $class );
}

=head3 Koha::Objects->new_from_dbic();

my $object = Koha::Object->new_from_dbic( $resultset );

=cut

sub new_from_dbic {
    my ( $class, $resultset ) = shift;
    my $self = { _resultset => $resultset };

    bless( $self, $class );
}

=head3 Koha::Objects->Find();

my $object = Koha::Object->Find($id);
my $object = Koha::Object->Find( { keypart1 => $keypart1, keypart2 => $keypart2 } );

=cut

sub Find {
    my ( $self, $id ) = @_;

    my $result = $self->_ResultSet()->find($id);

    my $object = $self->ObjectClass()->new_from_dbic( $result );

    return $object;
}

=head3 Koha::Objects->Search();

my @objects = Koha::Object->Search($params);

=cut

sub Search {
    my ( $self, $params ) = @_;

    if (wantarray) {
        my @dbic_rows = $self->_ResultSet()->search($params);

        return $self->_Wrap(@dbic_rows);

    }
    else {
        my $class = ref( $self );
        my $rs = $self->_ResultSet()->search($params);

        return $class->new_from_dbic($rs);
    }
}

=head3 Koha::Objects->Count();

my @objects = Koha::Object->Count($params);

=cut

sub Count {
    my ( $self, $params ) = @_;

    return $self->_ResultSet()->count($params);
}

=head3 Koha::Objects->_Wrap

Wraps the DBIC object in a corrosponding Koha object

=cut

sub _Wrap {
    my ( $self, @dbic_rows ) = @_;

    my @objects = map { $self->ObjectClass()->new_from_dbic( $_ ) } @dbic_rows;

    return @objects;
}

=head3 Koha::Objects->_ResultSet

Returns the internal resultset or creates it if undefined

=cut

sub _ResultSet {
    my ($self) = @_;

    $self->{_resultset} ||=
      Koha::Database->new()->schema()->resultset( $self->Type() );

    $self->{_resultset};
}

=head3 Type

The type method must be set for all child classes.
The value returned by it should be the DBIC resultset name.
For example, for holds, Type should return 'Reserve'.

=cut

sub Type { }

=head3 ObjectClass

This method must be set for all child classes.
The value returned by it should be the name of the Koha
object class that is returned by this class.
For example, for holds, ObjectClass should return 'Koha::Hold'.

=cut

sub ObjectClass { }

sub DESTROY { }

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
