package OpusVL::AppKitX::CMS::Controller::CMS::Elements;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
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

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }
    
    $c->stash->{section} = 'Elements';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Elements',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationName('Elements') {
    my ($self, $c) = @_;
    
    $c->stash->{elements} = [$c->model('CMS::Elements')->all];
}


#-------------------------------------------------------------------------------

sub new_element :Local :Args(0) :AppKitForm {
    my ($self, $c) = @_;

    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'New element',
        url     => $c->req->uri,
    };
    
    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $element = $c->model('CMS::Elements')->create({
            name => $form->param_value('name'),
        });
        
        $element->set_content($form->param_value('content'));
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

sub edit_element :Local :Args(1) :AppKitForm {
    my ($self, $c, $element_id) = @_;

    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Edit element',
        url     => $c->req->uri,
    };
    
    my $form    = $c->stash->{form};
    my $element = $c->model('CMS::Elements')->find({id => $element_id});
    
    $form->default_values({
        name    => $element->name,
        content => $element->content,
    });
    
    $form->process;
    
    if ($form->submitted_and_valid) {
        if ($form->param_value('name') ne $element->name) {
            $element->update({name => $form->param_value('name')});
        }

        if ($form->param_value('content') ne $element->content) {
            $element->set_content($form->param_value('content'));
        }
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

1;
