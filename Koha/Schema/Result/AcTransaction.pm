use utf8;
package Koha::Schema::Result::AcTransaction;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AcTransaction

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<ac_transactions>

=cut

__PACKAGE__->table("ac_transactions");

=head1 ACCESSORS

=head2 transaction_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 created

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 updated

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "transaction_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "created",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "updated",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</transaction_id>

=back

=cut

__PACKAGE__->set_primary_key("transaction_id");

=head1 RELATIONS

=head2 ac_transaction_accounts

Type: has_many

Related object: L<Koha::Schema::Result::AcTransactionAccount>

=cut

__PACKAGE__->has_many(
  "ac_transaction_accounts",
  "Koha::Schema::Result::AcTransactionAccount",
  { "foreign.transaction_id" => "self.transaction_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2015-06-19 10:41:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0BaZSqLo2MOuhP72I/TUIg


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
