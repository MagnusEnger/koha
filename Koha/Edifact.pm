package Koha::Edifact;

use strict;
use warnings;
use File::Slurp;
use Carp;
use Encode qw( from_to );
use Koha::Edifact::Segment;
use Koha::Edifact::Message;

my $separator = {
    component => q{\:},
    data      => q{\+},
    decimal   => q{.},
    release   => q{\?},
    reserved  => q{ },
    segment   => q{\'},
};

sub new {
    my ( $class, $param_hashref ) = @_;
    my $transmission;
    my $self = ();

    if ( $param_hashref->{filename} ) {
        if ( $param_hashref->{transmission} ) {
            carp
"Cannot instanitate $class : both filename and transmission passed";
            return;
        }
        $transmission = read_file( $param_hashref->{filename} );
    }
    else {
        $transmission = $param_hashref->{transmission};
    }
    $self->{transmission} = _init($transmission);

    bless $self, $class;
    return $self;
}

sub interchange_header {
    my ( $self, $field ) = @_;

# fields sender | recipient | DT of Prep : Control_reference | Application reference
    my %element = (
        sender                        => 1,
        recipient                     => 2,
        datetime                      => 3,
        interchange_control_reference => 4,
        application_reference         => 6,
    );
    if ( !exists $element{$field} ) {
        carp "No interchange header field $field available";
        return;
    }
    my $data = $self->{transmission}->[0]->elem( $element{$field} );
    if ( ref $data eq 'ARRAY' ) {
    }
    return $data;
}

sub interchange_trailer {
    my ( $self, $field ) = @_;
    my $trailer = $self->{transmission}->[-1];
    if ( $field eq 'interchange_control_count' ) {
        return $trailer->elem(0);
    }
    elsif ( $field eq 'interchange_control_reference' ) {
        return $trailer->elem(1);
    }
    carp "Trailer field $field not recognized";
    return;
}

sub new_data_iterator {
    my $self   = shift;
    my $offset = 0;
    while ( $self->{transmission}->[$offset]->tag() ne 'UNH' ) {
        ++$offset;
        if ( $offset == @{ $self->{transmission} } ) {
            carp 'Cannot find message start';
            return;
        }
    }
    $self->{data_iterator} = $offset;
    return 1;
}

sub next_segment {
    my $self = shift;
    if ( defined $self->{data_iterator} ) {
        my $seg = $self->{transmission}->[ $self->{data_iterator} ];
        if ( $seg->tag eq 'UNH' ) {

            $self->{msg_type} = $seg->elem( 1, 0 );
        }
        elsif ( $seg->tag eq 'LIN' ) {
            $self->{msg_type} = 'detail';
        }

        if ( $seg->tag ne 'UNZ' ) {
            $self->{data_iterator}++;
        }
        else {
            $self->{data_iterator} = undef;
        }
        return $seg;
    }
    return;
}

# for debugging return whole transmission
sub get_transmission {
    my $self = shift;

    return $self->{transmission};
}

sub message_type {
    my $self = shift;
    return $self->{msg_type};
}

sub _init {
    my $msg = shift;
    if ( !$msg ) {
        return;
    }
    if ( $msg =~ s/^UNA(.{6})// ) {
        if ( service_string_advice($1) ) {
            return segmentize($msg);

        }
        return;
    }
    else {
        my $s = substr $msg, 10;
        croak "File does not start with a Service string advice :$s";
    }
}

# return an array of message data which willbe used to
# create Message objects
sub message_array {
    my $self = shift;

    # return an array of array_refs 1 ref to a message
    my $msg_arr = [];
    my $msg     = [];
    my $in_msg  = 0;
    foreach my $seg ( @{ $self->{transmission} } ) {
        if ( $seg->tag eq 'UNH' ) {
            $in_msg = 1;
            push @{$msg}, $seg;
        }
        elsif ( $seg->tag eq 'UNT' ) {
            $in_msg = 0;
            if ( @{$msg} ) {
                push @{$msg_arr}, Koha::Edifact::Message->new($msg);
                $msg = [];
            }
        }
        elsif ($in_msg) {
            push @{$msg}, $seg;
        }
    }
    return $msg_arr;
}

#
# internal parsing routines used in _init
#
sub service_string_advice {
    my $ssa = shift;

    # At present this just validates that the ssa
    # is standard Edifact
    # TBD reset the seps if non standard
    if ( $ssa ne q{:+.? '} ) {
        carp " Non standard Service String Advice [$ssa]";
        return;
    }

    # else use default separators
    return 1;
}

sub segmentize {
    my $raw = shift;

    # In practice edifact uses latin-1 but check
    my $char_set = 'iso-8859-1';
    if ( $raw =~ m/^UNB[+]UNO(.)/ ) {
        $char_set = msgcharset($1);
    }
    from_to( $raw, $char_set, 'utf8' );

    my $re = qr{
(?>         # dont backtrack into this group
    [?].     # either the escape character
            # followed by any other character
     |      # or
     [^'?]   # a character that is neither escape
             # nor split
             )+
}x;
    my @segmented;
    while ( $raw =~ /($re)/g ) {
        push @segmented, Koha::Edifact::Segment->new( { seg_string => $1 } );
    }
    return \@segmented;
}

sub parse_seg {
    my $s = shift;

    my $e = {
        raw => $s,
        tag => substr( $s, 0, 3 ),
        data => get_elements( substr( $s, 3 ) ),
    };
    return $e;
}

sub get_elements {
    my $seg = shift;

    #my @elem_array = split /$separator{data}/, $seg;
    $seg =~ s/^[+]//;    # dont start with a dummy element`:w
    my @elem_array = map { components($_) } split /(?<![?])[+]/, $seg;

    return \@elem_array;
}

sub components {
    my $element = shift;
    my @c = split /(?<![?])\:/, $element;
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

sub msgcharset {
    my $code = shift;
    if ( $code =~ m/^[^ABCDEF]$/ ) {
        $code = 'default';
    }
    my %encoding_map = (
        A       => 'ascii',
        B       => 'ascii',
        C       => 'iso-8859-1',
        D       => 'iso-8859-1',
        E       => 'iso-8859-1',
        F       => 'iso-8859-1',
        default => 'iso-8859-1',
    );
    return $encoding_map{$code};
}

1;
