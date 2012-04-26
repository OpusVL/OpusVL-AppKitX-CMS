package OpusVL::AppKitX::CMS::Controller::CMS::Templates;

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
    
    $c->stash->{section} = 'Templates';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Templates',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationName('Templates') {
    my ($self, $c) = @_;
    
    $c->stash->{templates} = [$c->model('CMS::Templates')->all];
}


#-------------------------------------------------------------------------------

sub new_template :Local :Args(0) :AppKitForm {
    my ($self, $c) = @_;

    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'New template',
        url     => $c->req->uri,
    };
    
    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $template = $c->model('CMS::Templates')->create({
            name => $form->param_value('name'),
        });
        
        $template->set_content($form->param_value('content'));
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

sub edit_template :Local :Args(1) :AppKitForm {
    my ($self, $c, $template_id) = @_;

    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Edit template',
        url     => $c->req->uri,
    };
    
    my $form     = $c->stash->{form};
    my $template = $c->model('CMS::Templates')->find({id => $template_id});
    
    $form->default_values({
        name    => $template->name,
        content => $template->content,
    });
    
    $form->process;
    
    if ($form->submitted_and_valid) {
        if ($form->param_value('name') ne $template->name) {
            $template->update({name => $form->param_value('name')});
        }
        
        if ($form->param_value('content') ne $template->content) {
            $template->set_content($form->param_value('content'));
        }
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

1;
