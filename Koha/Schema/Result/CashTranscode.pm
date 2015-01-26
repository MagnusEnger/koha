use utf8;
package Koha::Schema::Result::CashTranscode;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::CashTranscode

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cash_transcode>

=cut

__PACKAGE__->table("cash_transcode");

=head1 ACCESSORS

=head2 code

  data_type: 'varchar'
  is_nullable: 0
  size: 10

=head2 description

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 100

=head2 income_group

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 taxrate

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=cut

__PACKAGE__->add_columns(
  "code",
  { data_type => "varchar", is_nullable => 0, size => 10 },
  "description",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 100 },
  "income_group",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "taxrate",
  { data_type => "varchar", is_nullable => 1, size => 10 },
);

=head1 PRIMARY KEY

=over 4

=item * L</code>

=back

=cut

__PACKAGE__->set_primary_key("code");

=head1 RELATIONS

=head2 cash_transactions

Type: has_many

Related object: L<Koha::Schema::Result::CashTransaction>

=cut

__PACKAGE__->has_many(
  "cash_transactions",
  "Koha::Schema::Result::CashTransaction",
  { "foreign.tcode" => "self.code" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2015-01-26 13:07:28
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:w/72TwUhzqEFnBzmdZTFXw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
