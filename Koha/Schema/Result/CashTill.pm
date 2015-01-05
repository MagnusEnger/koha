use utf8;
package Koha::Schema::Result::CashTill;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::CashTill

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<cash_till>

=cut

__PACKAGE__->table("cash_till");

=head1 ACCESSORS

=head2 tillid

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 description

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 branch

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 1
  size: 10

=cut

__PACKAGE__->add_columns(
  "tillid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "branch",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 1, size => 10 },
);

=head1 PRIMARY KEY

=over 4

=item * L</tillid>

=back

=cut

__PACKAGE__->set_primary_key("tillid");

=head1 RELATIONS

=head2 branch

Type: belongs_to

Related object: L<Koha::Schema::Result::Branch>

=cut

__PACKAGE__->belongs_to(
  "branch",
  "Koha::Schema::Result::Branch",
  { branchcode => "branch" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "RESTRICT",
    on_update     => "RESTRICT",
  },
);

=head2 cash_transactions

Type: has_many

Related object: L<Koha::Schema::Result::CashTransaction>

=cut

__PACKAGE__->has_many(
  "cash_transactions",
  "Koha::Schema::Result::CashTransaction",
  { "foreign.till" => "self.tillid" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-12-18 15:37:01
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ShBSZp/M0wap+7CKO55XDw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
