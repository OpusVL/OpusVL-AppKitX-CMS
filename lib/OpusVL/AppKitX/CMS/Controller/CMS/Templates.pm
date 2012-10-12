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
    appkit_css                  => [qw</static/css/bootstrap.css /static/css/jwysiwyg/jquery.wysiwyg.css /static/css/jwysiwyg/jquery.wysiwyg.modal.css /static/css/cms.css>],
    appkit_js                   => [qw< /static/js/bootstrap.js /static/js/wysiwyg/jquery.wysiwyg.js /static/js/wysiwyg/controls/wysiwyg.colorpicker.js /static/js/wysiwyg/controls/wysiwyg.cssWrap.js /static/js/wysiwyg/controls/wysiwyg.image.js /static/js/wysiwyg/controls/wysiwyg.link.js /static/js/wysiwyg/controls/wysiwyg.table.js /static/js/cms.js /static/js/bootstrap-button.js /static/js/bootstrap-transition.js /static/js/bootstrap-modal.js>],
    #appkit_js                   => [qw< /static/js/wysiwyg/jquery.wysiwyg.js /static/js/cms.js >],
    #appkit_js                     => ['/static/js/nicEdit.js', '/static/js/cms.js'],
    appkit_method_group         => 'Content Management',
    appkit_method_group_order   => 1,
    appkit_shared_module        => 'CMS',
    #appkit_css                  => ['/static/modules/cms/cms.css'],
);

 
#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;

    $c->forward('/modules/cms/site_validate');

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }
    
    $c->stash->{section} = 'Templates';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Templates',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };

    1;
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationName('Templates') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};
    my $templates = $c->model('CMS::Template')->search({
        -or => [
            site => $site->id,
            global => 1,
        ]
    });
    $c->stash->{templates} = [$templates->all];
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
        my $template = $c->model('CMS::Template')->create({
            name   => $form->param_value('name'),
            site   => $c->stash->{site}->id,
            global => $form->param_value('global')||0,
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
    my $template = $c->model('CMS::Template')->find({id => $template_id});
    
    $form->default_values({
        name    => $template->name,
        content => $template->content,
        global  => $template->global,
    });
    
    $form->process;
    
    if ($form->submitted_and_valid) {
        #if ($form->param_value('name') ne $template->name) {
            $template->update({
                name => $form->param_value('name'),
                global => $form->param_value('global')||0
            });
        #}
        
        if ($form->param_value('content') ne $template->content) {
            $template->set_content($form->param_value('content'));
        }
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

1;
