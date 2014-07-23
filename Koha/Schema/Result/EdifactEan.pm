use utf8;
package Koha::Schema::Result::EdifactEan;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::EdifactEan

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<edifact_ean>

=cut

__PACKAGE__->table("edifact_ean");

=head1 ACCESSORS

=head2 branchcode

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 ean

  data_type: 'varchar'
  is_nullable: 0
  size: 15

=head2 id_code_qualifier

  data_type: 'varchar'
  default_value: 14
  is_nullable: 0
  size: 3

=cut

__PACKAGE__->add_columns(
  "branchcode",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "ean",
  { data_type => "varchar", is_nullable => 0, size => 15 },
  "id_code_qualifier",
  { data_type => "varchar", default_value => 14, is_nullable => 0, size => 3 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-05-29 11:15:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:MKXue/6zd/QCXpZp3astxg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->belongs_to('branch',
    "Koha::Schema::Result::Branch",
    { 'branchcode' => 'branchcode' },
    {
        is_deferrable => 1,
        join_type => 'LEFT',
        on_delete => 'CASCADE',
        on_update => 'CASCADE',
    },
);

1;
