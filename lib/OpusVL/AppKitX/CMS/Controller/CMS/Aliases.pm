package OpusVL::AppKitX::CMS::Controller::CMS::Aliases;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    appkit_name                 => 'CMS',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    #appkit_js                     => ['/static/js/cms.js', '/static/js/nicEdit.js', '/static/js/src/addElement/addElement.js'],
    # appkit_method_group         => 'Extension A',
    # appkit_method_group_order   => 2,
    appkit_shared_module        => 'CMS',
    #appkit_css                  => ['/static/modules/cms/cms.css'],
);

 
#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;

    $c->stash->{section} = 'Aliases';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Aliases',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationHome :NavigationName('Aliases') {
    my ($self, $c) = @_;
    
    $c->stash->{aliases} = [$c->model('CMS::Aliases')->all];
}


#-------------------------------------------------------------------------------

1;