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
    appkit_css                  => [qw< /static/js/redactor/redactor.css /static/css/bootstrap.css >],
    appkit_js                   => [qw< /static/js/bootstrap.js /static/js/redactor/redactor.js >],
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

    #$c->forward('/modules/cms/site_validate');
    
    #$c->stash->{section} = 'Templates';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Templates',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}

#-------------------------------------------------------------------------------

sub base :Chained('/') :PathPart('') :CaptureArgs(0) {
    my ($self, $c, $site_id) = @_;  
}

sub templates :Chained('base') :PathPart('template') :CaptureArgs(2) {
    my ($self, $c, $site_id, $template_id)  = @_;
    $c->forward('/modules/cms/sites/base', [ $site_id ]);

    my $site = $c->stash->{site};
    my $template    = $c->model('CMS::Template')->find({ site => $site->id, id => $template_id });

    unless ($template) {
        $c->flash(error_msg => "No such template");
        $c->res->redirect($c->uri_for($self->action_for('index'), $site->id));
        $c->detach;
    }
    
    $c->stash(
        _template => $template,
        site     => $site,
    );
}

#-------------------------------------------------------------------------------

sub index :Chained('/modules/cms/sites/base') :PathPart('list') :Args(0) {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};
    if ($site) {
        my $templates = $c->model('CMS::Template')->search({
            -or => [
                site => $site->id,
                global => 1,
            ]
        });
        $c->stash(
            templates => [$templates->all],
            site      => $site,
        );
    }
}

#-------------------------------------------------------------------------------

sub new_template :Chained('/modules/cms/sites/base') :Args(0) :PathPart('template/new') :AppKitForm {
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
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $c->stash->{site}->id ]));
    }

    if ($c->req->param('cancel')) {
       $c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $c->stash->{site}->id ]));
       $c->detach;
    }

    $c->stash->{elements} = [ $c->stash->{site}->elements->available->all ];
    $c->stash->{pages} = [ $c->stash->{site}->pages->published->all ];
}


#-------------------------------------------------------------------------------

sub edit_template :Chained('templates') :PathPart('edit') :Args(0) :AppKitForm {
    my ($self, $c) = @_;

    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Edit template',
        url     => $c->req->uri,
    };

    my $form     = $c->stash->{form};
    my $template = $c->stash->{_template};
    my $site     = $c->stash->{site};
    
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
        
        $c->res->redirect($c->uri_for($self->action_for('index'), [ $site->id ]));
        $c->detach;
    }

    if ($c->req->param('cancel')) {
       $c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $c->stash->{site}->id ]));
       $c->detach;
    }
}


#-------------------------------------------------------------------------------

1;
