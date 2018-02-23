package HTML::FormFu::Element::NumberField;

use Moose;

extends 'HTML::FormFu::Element::Text';

after BUILD => sub {
    my $self = shift;
    
    $self->field_type('number');
};
    
__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

HTML::FormFu::Element::NumberField - Number element 

=head1 SYNOPSIS

  ---
  elements:
    - type: NumberField

=head1 DESCRIPTION

This produces an input of type number.

=head1 COPYRIGHT and LICENSE

Copyright (C) 2011 OpusVL

This software is licensed according to the "IP Assignment Schedule" provided with the development project.


