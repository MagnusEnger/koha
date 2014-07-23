package Koha::Edifact::Segment;

use strict;
use warnings;

sub new {
    my ( $class, $parm_ref ) = @_;
    my $self = {};
    if ( $parm_ref->{seg_string} ) {
        $self = _parse_seg( $parm_ref->{seg_string} );
    }

    bless $self, $class;
    return $self;
}

sub tag {
    my $self = shift;
    return $self->{tag};
}

# return specified element may be data or an array ref if components
sub elem {
    my ( $self, $element_number, $component_number ) = @_;
    if ( $element_number < @{ $self->{elem_arr} } ) {

        my $e = $self->{elem_arr}->[$element_number];
        if ( defined $component_number ) {
            if ( ref $e eq 'ARRAY' ) {
                if ( $component_number < @{$e} ) {
                    return $e->[$component_number];
                }
            }
            elsif ( $component_number == 0 ) {

                # a string could be an element with a single component
                return $e;
            }
            return;
        }
        else {
            return $e;
        }
    }
    return;    #element undefined ( out of range
}

sub element {
    my ( $self, @params ) = @_;

    return $self->elem(@params);
}

sub as_string {
    my $self = shift;

    my $string = $self->{tag};
    foreach my $e ( @{ $self->{elem_arr} } ) {
        $string .= q|+|;
        if ( ref $e eq 'ARRAY' ) {
            $string .= join q{:}, @{$e};
        }
        else {
            $string .= $e;
        }
    }

    return $string;
}

# parse a string into fields
sub _parse_seg {
    my $s = shift;

    my $e = {

        #        raw => $s,
        tag      => substr( $s,                0, 3 ),
        elem_arr => _get_elements( substr( $s, 3 ) ),
    };
    return $e;
}

##
# String parsing
#

sub _get_elements {
    my $seg = shift;

    #my @elem_array = split /$separator{data}/, $seg;
    $seg =~ s/^[+]//;    # dont start with a dummy element`
    my @elem_array = map { _components($_) } split /(?<![?])[+]/, $seg;

    return \@elem_array;
}

sub _components {
    my $element = shift;
    my @c = split /(?<![?])[:]/, $element;
    if ( @c == 1 ) {     # single element return a string
        return de_escape( $c[0] );
    }
    @c = map { de_escape($_) } @c;
    return \@c;
}

sub de_escape {
    my $string = shift;

    # remove escaped characters from the component string
    $string =~ s/[?]([:?+'])/$1/g;
    return $string;
}
1;
