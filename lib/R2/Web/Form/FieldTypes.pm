package R2::Web::Form::FieldTypes;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw( Date );
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

use Chloro::FieldType;
use R2::Types;

use constant { Date => Chloro::FieldType->new( type => 'R2.Type.Date' ),
             };

1;
