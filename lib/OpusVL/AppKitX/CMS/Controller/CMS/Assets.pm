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
    appkit_css                  => ['/static/css/cms.css'],
    appkit_js                   => ['/static/js/cms.js'],
    #appkit_js                   => ['/static/js/facebox.js', '/static/js/cms.js'],
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
    
    $c->stash->{section} = 'Assets';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Assets',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };

    1;
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationName('Assets') {
    my ($self, $c) = @_;
    
    $c->stash->{assets} = [$c->model('CMS::Asset')
        ->search({
            -or => [
                site   => $c->stash->{site}->id,
                global => 1,
            ]
        })
        ->published->all];
}


#-------------------------------------------------------------------------------

sub upload_asset :Local :Args(0) {
    my ($self, $c) = @_;

    $self->add_final_crumb($c, "Upload assets");
}


#-------------------------------------------------------------------------------

sub new_asset :Local :Args(0) :AppKitForm {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};

    $self->add_final_crumb($c, "New asset");
    
    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $asset = $c->model('CMS::Asset')->create({
            description => $form->param_value('description'),
            mime_type   => $form->param_value('mime_type'),
            filename    => $form->param_value('filename'),
            site        => $site->id,
            global      => $form->param_value('global')||0,
        });
        
        $asset->set_content($form->param_value('content'));
        
        $c->flash->{status_msg} = 'New asset created';
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

sub edit_asset :Local :Args(1) :AppKitForm {
    my ($self, $c, $asset_id) = @_;

    $self->add_final_crumb($c, "Edit asset");

    my $restricted_row = $c->model('CMS::Parameter')->find({ parameter => 'Restricted' });

    if ($restricted_row) {
        if ($c->user->users_parameters->find({ parameter_id => $restricted_row->id })) {
            unless ($c->model('CMS::AssetUser')->find({ asset_id => $asset_id, user_id => $c->user->id })) {
                $c->detach('/access_denied');
            }
        }
    }

    my $form  = $c->stash->{form};
    my $asset = $c->model('CMS::Asset')->published->find({id => $asset_id});
    
    if ($asset->mime_type =~ /^text/) {
        # Add in-line edit control to form
        my $fieldset = $form->get_all_element({name => 'asset_details'});
        $fieldset->element({
            type  => 'Textarea',
            name  => 'content',
            id    => 'wysiwyg',
            label => 'Content',
        });
        
        $form->default_values({
            content => $asset->content,
        });
    }
    
    $form->default_values({
        description => $asset->description,
        global      => $asset->global,
    });
    
    $form->process;
    
    if ($form->submitted_and_valid) {
        #if ($form->param_value('description') ne $asset->description) {
            $asset->update({description => $form->param_value('description'), global => $form->param_value('global')||0});
        #}
        
        if (my $file = $c->req->upload('file')) {
            $asset->set_content($file->slurp);

            $asset->update({
                filename  => $file->basename,
                mime_type => $file->type,
            });
        } else {
            if ($form->param_value('content') ne $asset->content) {
                $asset->set_content($form->param_value('content'));
            }
        }
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

sub upload_assets :Local :Args(1) {
    my ($self, $c, $global) = @_;
    
    $global = $global eq 'on' ? 1 : 0;
    my $asset_rs = $c->model('CMS::Asset');
    if (my $file = $c->req->upload('file')) {
        my $asset = $asset_rs->create({
            mime_type   => $file->type,
            filename    => $file->basename,
            site        => $c->stash->{site}->id,
            global      => $global,
        });

        $asset->set_content($file->slurp);       
    }
}


#-------------------------------------------------------------------------------

sub delete_asset :Local :Args(1) :AppKitForm {
    my ($self, $c, $asset_id) = @_;

    $self->add_final_crumb($c, "Delete asset");
    
    my $form  = $c->stash->{form};
    my $asset = $c->model('CMS::Asset')->find({id => $asset_id});

    if ($form->submitted_and_valid) {
        $asset->remove;
        
        $c->flash->{status_msg} = "Asset deleted";
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }
    
    $c->stash->{asset} = $asset;
}


#-------------------------------------------------------------------------------

1;
