package OpusVL::AppKitX::CMS::Controller::CMS::Assets;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    appkit_name                 => 'Assets',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_css                  => ['/static/css/bootstrap.css', '/static/js/datatables/css/jquery.dataTables.css'],
    appkit_js                   => ['/static/js/cms.js', '/static/js/bootstrap.js', '/static/js/facebox.js', '/static/js/datatables/js/jquery.dataTables.min.js'],
    #appkit_js                   => ['/static/js/facebox.js', '/static/js/cms.js'],
    appkit_method_group         => 'Content Management',
    appkit_method_group_order   => 1,
    appkit_shared_module        => 'CMS',
    #appkit_css                  => ['/static/modules/cms/cms.css'],
);

 
#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;

    #$c->forward('/modules/cms/site_validate');
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Assets',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}

#-------------------------------------------------------------------------------

sub base :Chained('/') :PathPart('assets') :CaptureArgs(0) :AppKitFeature('Assets - Read Access') {
    my ($self, $c) = @_;
}

sub assets :Chained('base') :PathPart('asset') :CaptureArgs(2) :AppKitFeature('Assets - Read Access') {
    my ($self, $c, $site_id, $asset_id) = @_;
    $c->forward('/modules/cms/sites/base', [ $site_id ]);

    my $asset = $c->model('CMS::Asset')->find({ site => $site_id, id => $asset_id });

    unless ($asset) {
        $c->flash(error_msg => "No such asset");
        $c->res->redirect($c->uri_for($self->action_for('index'), [ $site_id ]));
        $c->detach;
    }
    
    $c->stash( asset => $asset );

}

#-------------------------------------------------------------------------------

sub index :Chained('/modules/cms/sites/base') :PathPart('assets/list') :Args(0) :AppKitFeature('Assets - Read Access') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};

    $c->stash->{assets} = [$c->model('CMS::Asset')
        ->search({
            -or => [
                site   => $site->id,
                global => 1,
            ]
        })
        ->published->all];
}


#-------------------------------------------------------------------------------

sub upload_asset :Chained('/modules/cms/sites/base') :PathPart('assets/upload') :Args(0) :AppKitFeature('Assets - Write Access') {
    my ($self, $c) = @_;

    $self->add_final_crumb($c, "Upload assets");
}


#-------------------------------------------------------------------------------

sub new_asset :Chained('/modules/cms/sites/base') :PathPart('assets/new') :Args(0) :AppKitForm :AppKitFeature('Assets - Write Access') {
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
        $c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $site->id ]));
    }

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($self->action_for('index'), [ $site->id ]));
        $c->detach;
    }
}


#-------------------------------------------------------------------------------

sub edit_asset :Chained('assets') :PathPart('edit') :Args(0) :AppKitForm :AppKitFeature('Assets - Write Access') {
    my ($self, $c) = @_;
    my $site  = $c->stash->{site};
    my $asset = $c->stash->{asset};

    $self->add_final_crumb($c, "Edit asset");

    my $restricted_row = $c->model('CMS::Parameter')->find({ parameter => 'Restricted' });

    if ($restricted_row) {
        if ($c->user->users_parameters->find({ parameter_id => $restricted_row->id })) {
            unless ($c->model('CMS::AssetUser')->find({ asset_id => $asset->id, user_id => $c->user->id })) {
                $c->detach('/access_denied');
            }
        }
    }

    my $form  = $c->stash->{form};
    
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
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $site->id ]));
    }

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($self->action_for('index'), [ $site->id ]));
        $c->detach;
    }
}


#-------------------------------------------------------------------------------

sub upload_assets :Chained('/modules/cms/sites/base') :Args(0) :AppKitFeature('Assets - Write Access') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};
    
    my $asset_rs = $c->model('CMS::Asset');
    if (my $file = $c->req->upload('file')) {
        my $asset = $asset_rs->create({
            mime_type   => $file->type,
            filename    => $file->basename,
            site        => $site->id,
        });

        $asset->set_content($file->slurp);       
    }
}

sub upload_assets_global :Chained('/modules/cms/sites/base') :Args(0) :AppKitFeature('Assets - Write Access') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};
    
    my $asset_rs = $c->model('CMS::Asset');
    if (my $file = $c->req->upload('file')) {
        my $asset = $asset_rs->create({
            mime_type   => $file->type,
            filename    => $file->basename,
            site        => $site->id,
            global      => 1,
        });

        $asset->set_content($file->slurp);       
    }
}


#-------------------------------------------------------------------------------

sub delete_asset :Chained('assets') :PathPart('delete') :Args(0) :AppKitForm :AppKitFeature('Assets - Write Access') {
    my ($self, $c) = @_;
    my $site  = $c->stash->{site};
    my $asset = $c->stash->{asset};
    my $form  = $c->stash->{form};

    $self->add_final_crumb($c, "Delete asset");

    if ($form->submitted_and_valid) {
        $asset->remove;
        
        $c->flash->{status_msg} = "Asset deleted";
        $c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $site->id ]));
        $c->detach;
    }

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($self->action_for('index'), [ $site->id ]));
        $c->detach;
    }
}


#-------------------------------------------------------------------------------

1;
