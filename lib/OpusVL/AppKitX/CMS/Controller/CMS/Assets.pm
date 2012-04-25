package OpusVL::AppKitX::CMS::Controller::CMS::Assets;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    appkit_name                 => 'CMS',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
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
    
    $c->stash->{section} = 'Assets';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Assets',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationName('Assets') {
    my ($self, $c) = @_;
    
    $c->stash->{assets} = [$c->model('CMS::Assets')->all];
}


#-------------------------------------------------------------------------------

sub new_asset :Local :Args(0) :AppKitForm {
    my ($self, $c) = @_;

    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'New asset',
        url     => $c->req->uri,
    };
    
    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $file  = $c->req->upload('file');
        my $asset = $c->model('CMS::Assets')->create({
            description => $form->param_value('description'),
            mime_type   => $file->type,
            filename    => $file->basename,
        });
        
        $asset->set_content($file->slurp);
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

sub edit_asset :Local :Args(1) :AppKitForm {
    my ($self, $c, $asset_id) = @_;

    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Edit asset',
        url     => $c->req->uri,
    };
    
    my $form  = $c->stash->{form};
    my $asset = $c->model('CMS::Assets')->find({id => $asset_id});
    
    if ($asset->mime_type =~ /^text/) {
        # Add in-line edit control to form
        my $fieldset = $form->get_all_element({name => 'asset_details'});
        $fieldset->element({
            type  => 'Textarea',
            name  => 'content',
            label => 'Content',
        });
        
        $form->default_values({
            content => $asset->content,
        });
    }
    
    $form->default_values({
        description => $asset->description,
    });
    
    $form->process;
    
    if ($form->submitted_and_valid) {
        if ($form->param_value('description') ne $asset->description) {
            $asset->update({description => $form->param_value('description')});
        }
        
        if (my $file = $c->req->upload('file')) {
            $asset->set_content($file->slurp);
        } else {
            if ($form->param_value('content') ne $asset->content) {
                $asset->set_content($form->param_value('content'));
            }
        }
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

1;