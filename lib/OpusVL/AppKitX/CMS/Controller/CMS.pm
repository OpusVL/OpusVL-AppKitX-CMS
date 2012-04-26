package OpusVL::AppKitX::CMS::Controller::CMS;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';

__PACKAGE__->config
(
    appkit_name                 => 'CMS',
    # appkit_icon                 => 'static/images/flagA.jpg',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_js                     => ['/static/js/nicEdit.js', '/static/js/cms.js'],
    # appkit_method_group         => 'Extension A',
    # appkit_method_group_order   => 2,
    # appkit_shared_module        => 'ExtensionA',
);

sub auto :Private {
    my ($self, $c) = @_;
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'CMS',
        url     => $c->uri_for( $c->controller('Modules::CMS::Pages')->action_for('index'))
    };
}

# sub home
#     :Path
#     :Args(0)
#     :NavigationHome
#     :AppKitFeature('Extension A')
# {
#     my ($self, $c) = @_;
# }

=head1 NAME

OpusVL::AppKitX::CMS::Controller:CMS - 

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

=head1 AUTHOR

=head1 COPYRIGHT and LICENSE

Copyright (C) 2012 OpusVL

This software is licensed according to the "IP Assignment Schedule" provided with the development project.

=cut

