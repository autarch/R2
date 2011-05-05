package R2::Web::Form::ContactNote;

use Moose;
use Chloro;

use List::AllUtils qw( any );
use R2::Schema;
use R2::Types qw( Str );
use R2::Util qw( string_is_empty );

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Form::FromSchema' => {
    classes => ['R2::Schema::ContactNote'],
    skip    => [qw( contact_id reversal_blob user_id note_datetime )],
};

field note_datetime => (
    isa       => 'DateTime',
    required  => 1,
    extractor => '_extract_note_datetime',
);

sub _extract_note_datetime {
    my $self   = shift;
    my $params = shift;

    return
        if any { string_is_empty($_) } @{$params}{ 'note_date', 'note_time' };

    return (
        $self->_parse_datetime("$params->{note_date} $params->{note_time}"),
        'note_date', 'note_time',
    );
}

1;

