package OpusVL::AppKitX::CMS::Controller::CMS::Ajax;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller' }
with 'OpusVL::AppKit::RolesFor::Controller::GUI';

__PACKAGE__->config
(
    appkit_name                 => 'CMS',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_js                     => ['/static/js/nicEdit.js', '/static/js/cms.js'],
    # appkit_method_group         => 'Extension A',
    # appkit_method_group_order   => 2,
    appkit_shared_module        => 'CMS',
    #appkit_css                  => ['/static/modules/cms/cms.css'],
);


#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;
    $c->stash->{no_wrapper} = 1;
    #$c->stash->{current_view} = 'CMS::Ajax';
}

sub index :Path :Args(0) {
    my ($self, $c) = @_;
}

sub list_elements :Local :Args(0) {
    my ($self, $c) = @_;
    #$c->stash->{template} = 'list_elements.tt';
    $c->stash->{elements} = $c->model('CMS::Elements')->published;
}

sub load_controls :Local :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{assets}   = $c->model('CMS::Assets')->published;
    $c->stash->{elements} = $c->model('CMS::Elements')->published;
    $c->stash->{pages}    = $c->model('CMS::Pages')->published;
    
    if (my $page_id = $c->req->param('page_id')) {
        $c->stash->{page} = $c->model('CMS::Pages')->published->find({id => $page_id});
    }
}

return qr|I'll get you next time gadget, next time!|; 
