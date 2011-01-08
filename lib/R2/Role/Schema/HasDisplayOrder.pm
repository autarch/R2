package R2::Role::Schema::HasDisplayOrder;

use strict;
use warnings;
use namespace::autoclean;

use Fey::Literal::Function;
use Fey::Literal::Term;
use Fey::Placeholder;
use R2::Schema;
use R2::Types qw( Str );

use MooseX::Role::Parameterized;

parameter 'related_column' => (
    isa      => 'Fey::Column',
    required => 1,
);

my $_insert_wrapper = sub {
    my $table  = shift;
    my $column = shift;

    my $max_func = Fey::Literal::Function->new(
        'MAX',
        $table->column('display_order')
    );

    my $plus_one = Fey::Literal::Term->new( $max_func, ' + 1' );

    my $coalesce = Fey::Literal::Function->new(
        'COALESCE',
        $plus_one,
        1,
    );

    my $display_order_select_base
        = R2::Schema->SQLFactoryClass()->new_select( auto_placeholders => 0 );
    #<<<
    $display_order_select_base
        ->select($coalesce)
        ->from  ($table);
    #>>>

    return sub {
        my $orig  = shift;
        my $class = shift;
        my %p     = @_;

        unless ( exists $p{display_order} ) {
            my $select = $display_order_select_base->clone()
                ->where( $column, '=', $p{ $column->name() } );

            $p{display_order} = $select;
        }

        return $class->$orig(%p);
    };
};

my $_delete_wrapper = sub {
    my $table  = shift;
    my $column = shift;

    my $minus_one
        = Fey::Literal::Term->new( $table->column('display_order'), ' - 1' );

    my $reorder_update = R2::Schema->SQLFactoryClass()->new_update();
    #<<<
    $reorder_update
        ->update($table)
        ->set   ( $table->column('display_order'), $minus_one )
        ->where ( $table->column('display_order'), '>', Fey::Placeholder->new() )
        ->and   ( $column, '=', Fey::Placeholder->new() );
    #>>>

    my $col_name = $column->name();

    return sub {
        my $orig = shift;
        my $self = shift;

        my $dbh = $self->_dbh($reorder_update);
        my $sql = $reorder_update->sql($dbh);

        my $display_order     = $self->display_order();
        my $related_col_value = $self->$col_name();

        R2::Schema->RunInTransaction(
            sub {
                $self->$orig(@_);

                $dbh->do( $sql, {}, $display_order, $related_col_value );
            }
        );
    };
};

role {
    my $p     = shift;
    my %extra = @_;

    my $table = $extra{consumer}->table();

    my $column = $p->related_column();

    around insert => $_insert_wrapper->( $table, $column );

    around delete => $_delete_wrapper->( $table, $column );

    my $col_name = $column->name();

    method _display_order_is_unique => sub {
        my $self      = shift;
        my $p         = shift;
        my $is_insert = shift;

        return unless defined $p->{display_order};

        # It's a SQL object
        return if blessed $p->{display_order};

        if ($is_insert) {
            return
                unless $self->new(
                $col_name     => $p->{$col_name},
                display_order => $p->{display_order},
                );
        }
        else {
            return
                unless defined $p->{display_order}
                    && $p->{display_order} != $self->display_order();

            return
                unless $self->new(
                $col_name     => $self->$col_name(),
                display_order => $p->{display_order},
                );
        }

        return {
            field => 'display_order',
            message =>
                "There is already a field at this position - $p->{display_order}",
        };
    };
};

1;
