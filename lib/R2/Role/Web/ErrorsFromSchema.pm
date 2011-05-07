package R2::Role::Web::ErrorsFromSchema;

use namespace::autoclean;

use Moose::Role;

use Chloro::Error::Field;
use Chloro::Error::Form;
use Chloro::ErrorMessage;
use List::AllUtils qw( any );

sub _process_errors {
    my $self            = shift;
    my $errors          = shift;
    my $field_resultset = shift;
    my $form_resultset  = shift;
    my $fields_from     = shift;
    my $skip            = shift;

    return unless @{$errors};

    for my $error ( @{$errors} ) {
        if ( my $field = delete $error->{field} ) {

            # If we try to validate an insert when we've left a field out of
            # the form (like EmailAddress.contact_id), we'll get an error, but
            # it should be ignored.
            next if $skip->{$field};

            my $field_obj = $fields_from->get_field($field)
                or next;

            my $result = $field_resultset->result_for($field);

            if ( $error->{category} eq 'missing' ) {
                next
                    if any { $_->message()->category() eq 'missing' }
                    $result->errors();
            }

            $result->add_error(
                Chloro::Error::Field->new(
                    field   => $field_obj,
                    message => Chloro::ErrorMessage->new($error),
                )
            );
        }
        else {
            $form_resultset->add_form_error(
                Chloro::Error::Form->new(
                    message => Chloro::ErrorMessage->new($error)
                )
            );
        }
    }
}

1;
