package OpusVL::AppKitX::CMS::Controller::CMS::Pages;

use 5.010;
use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    appkit_name                 => 'CMS',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_css                  => [qw</static/css/bootstrap.css /static/css/jwysiwyg/jquery.wysiwyg.css /static/css/jwysiwyg/jquery.wysiwyg.modal.css>],
    appkit_js                   => [qw< /static/js/bootstrap.js /static/js/wysiwyg/jquery.wysiwyg.js /static/js/wysiwyg/controls/wysiwyg.colorpicker.js /static/js/wysiwyg/controls/wysiwyg.cssWrap.js /static/js/wysiwyg/controls/wysiwyg.image.js /static/js/wysiwyg/controls/wysiwyg.link.js /static/js/wysiwyg/controls/wysiwyg.table.js /static/js/cms.js /static/js/bootstrap-button.js /static/js/bootstrap-transition.js /static/js/bootstrap-modal.js>],
    #appkit_js                     => ['/static/js/cms.js', '/static/js/nicEdit.js', '/static/js/src/addElement/addElement.js'],
    appkit_method_group         => 'Content Management',
    appkit_method_group_order   => 1,
    appkit_shared_module        => 'CMS',
    #appkit_css                  => ['/static/modules/cms/cms.css'],
);

 
#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;

    $c->stash->{section} = 'Pages';
    $c->forward('/modules/cms/site_validate');
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Pages',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };

    1;
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationHome :NavigationName('Pages') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};

    $c->stash->{pages} = [ $c->model('CMS::Page')
        ->search({
            site => $site->id,
            -or => [
                status => 'published',
                status => 'draft',
            ],
        }, { order_by => { '-asc' => 'url' }}) ];
}


#-------------------------------------------------------------------------------

sub new_page :Local :Args(0) :AppKitForm {
    my ($self, $c) = @_;
    my $site       = $c->stash->{site};

    my $templates = $c->model('CMS::Template')
        ->search({ site => $site->id });
    if ($templates->count < 1) {
        $c->flash->{error_msg} = "You may want to setup a template before you create a page";
        $c->res->redirect($c->uri_for($c->controller('Modules::CMS::Templates')->action_for('new_template')));
        $c->detach;
    }

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }
    
    $c->stash->{element_rs} = $c->model('CMS::Element');
    $self->add_final_crumb($c, "New page");

    my $form = $c->stash->{form};
    
    $form->get_all_element({name=>'template'})->options(
        [map {[$_->id, $_->name]} $c->model('CMS::Template')->all]
    );
    $form->get_all_element({name=>'parent'})->options(
        [map {[$_->id, $_->breadcrumb . " - " . $_->url]} $c->model('CMS::Page')->all]
    );

    # This part was throwing out undefined value as a HASH reference errors
    # before validating the $c->req->body_params
    $form->default_values({
        parent => $c->req->param('parent_id'),
    }) if $c->req->body_params->{parent_id};

    $form->process;
    
    if ($form->submitted_and_valid) {
        my $url = $form->param_value('url');
        unless ($url =~ m!^/!) {$url = "/$url"}

        my $status = $c->req->body_params->{preview} ?
            'preview' : 'published';

        my $page = $c->model('CMS::Page')->create({
            url         => $url,
            description => $form->param_value('description'),
            title       => $form->param_value('title'),
            h1          => $form->param_value('h1'),
            priority    => $form->param_value('priority') || undef,
            breadcrumb  => $form->param_value('breadcrumb'),
            template_id => $form->param_value('template') || undef,
            parent_id   => $form->param_value('parent') || undef,
            site        => $site->id,
            status      => $status,
            created_by  => $c->user->id,
        });
        
        $page->set_content($form->param_value('content'));

        if ($status eq 'preview') {
            $c->res->redirect($c->uri_for($c->controller->action_for('preview'), $page->id, 0));
            $c->detach;
        }

        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

sub edit_page :Local :Args(1) :AppKitForm {
    my ($self, $c, $page_id) = @_;
    my $site = $c->stash->{site};
    
    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }
    
    $self->add_final_crumb($c, "Edit page");

    my $page = $c->model('CMS::Page')->find({id => $page_id});
    my $form = $c->stash->{form};
        
    $form->get_all_element({name=>'template'})->options(
        [map {[$_->id, $_->name]} $c->model('CMS::Template')->all]
    );
    $form->get_all_element({name=>'parent'})->options(
        [map {[$_->id, $_->breadcrumb . " - " . $_->url]} $c->model('CMS::Page')->all]
    );
    
    my $aliases_fieldset = $form->get_all_element({name=>'page_aliases'});
    if (my @aliases = $page->search_related('aliases')) {
        foreach my $alias (@aliases) {
            $aliases_fieldset->element({
                type     => 'Multi',
                label    => 'URL',
                elements => [
                    {
                        type  => 'Text',
                        name  => 'alias_url_' . $alias->id,
                        value => $alias->url,
                    },
                    {
                        type  => 'Checkbox',
                        name  => 'delete_alias_' . $alias->id,
                        label => 'Delete',
                    },
                ]
            });
        }
    } else {
        $aliases_fieldset->element({
            type    => 'Block',
            tag     => 'p',
            content => 'No aliases have been created for this page',
        });
    }
    
    my $defaults = {
        url         => $page->url,
        description => $page->description,
        title       => $page->title,
        h1          => $page->h1,
        breadcrumb  => $page->breadcrumb,
        template    => $page->template_id,
        parent      => $page->parent_id,
        content     => $page->content,
        priority    => $page->priority,
    };
    
    $self->construct_attribute_form($c, 'CMS::PageAttributeDetail');

    my @fields = $c->model('CMS::PageAttributeDetail')->active->all;
    for my $field (@fields)
    {
        my $value = $page->page_attribute($field);
        $defaults->{'global_fields_' . $field->code} = $value;
    }
    
    $form->default_values($defaults);
    $form->process;

    if ($form->submitted_and_valid) {
        my $url = $form->param_value('url');
        unless ($url =~ m!^/!) {$url = "/$url"}

        if ($c->req->body_params->{preview}) {
            my $page_draft;
            if ($page->content ne $form->param_value('content')) {
                $page_draft = $c->model('CMS::PageDraft')->create({
                    created_by => $c->user->id,
                    page_id    => $page->id,
                    status     => 'draft',
                });

                if ($page_draft) {
                    $page_draft->create_draft($form->param_value('content'));
                }
            }
            else {
                $c->flash->{status_msg} = "No content was altered, so no draft created";
                $c->res->redirect($c->req->uri);
                $c->detach;
            }

            my $final_id = $page_draft ? $page_draft->id : 0;
            $c->res->redirect($c->uri_for($self->action_for('preview'), $page->id, $final_id));
            $c->detach;
        }

        $page->update({
            url         => $url,
            description => $form->param_value('description'),
            title       => $form->param_value('title'),
            h1          => $form->param_value('h1'),
            priority    => $form->param_value('priority') || undef,
            breadcrumb  => $form->param_value('breadcrumb'),
            template_id => $form->param_value('template') || undef,
            parent_id   => $form->param_value('parent') || undef,
            site        => $site->id,
        });
        
        if ($page->content ne $form->param_value('content')) {
            $page->set_content($form->param_value('content'));
        }
        
        if (my $file  = $c->req->upload('new_att_file')) {
            my $attachment = $page->create_related('attachments', {
                filename    => $file->basename,
                mime_type   => $file->type,
                description => $form->param_value('new_att_desc'),
                priority    => $form->param_value('new_att_priority') || undef,
            });
            
            $attachment->set_content($file->slurp);
        }
        
        PARAM: foreach my $param (keys %{$c->req->params}) {
            if ($param =~ /delete_alias_(\d+)/) {
                if (my $alias = $page->find_related('aliases', {id => $1})) {
                    $alias->delete;
                }
            }

            if ($param =~ /alias_url_(\d+)/) {
                if (my $alias = $page->find_related('aliases', {id => $1})) {
                    my $alias_url = $form->param_value($param);
                    unless ($alias_url =~ m!^/!) {$alias_url = "/$url"}
                    if ($alias_url ne $alias->url) {
                        $alias->update({url => $alias_url});
                    }
                }
            }
        }
        
        if (my $alias_url = $form->param_value('new_alias_url')) {
            unless ($alias_url =~ m!^/!) {$alias_url = "/$url"}
            $page->create_related('aliases', {url => $alias_url});
        }

        $self->update_page_attributes($c, $page);
        
        $c->flash->{status_msg} = "Your changes have been saved";
        $c->res->redirect($c->req->uri);
        $c->detach;
    }
    
    $c->stash->{page} = $page;
}


#-------------------------------------------------------------------------------

sub delete_page :Local :Args(1) :AppKitForm {
    my ($self, $c, $page_id) = @_;
    
    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }
    
    $self->add_final_crumb($c, "Delete page");

    my $page = $c->model('CMS::Pages')->find({id => $page_id});
    my $form = $c->stash->{form};
    
    if ($form->submitted_and_valid) {
        $page->remove;
        
        $c->flash->{status_msg} = "Page deleted";
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }

    $c->stash->{page} = $page;
}


#-------------------------------------------------------------------------------

sub save_preview :Local :Args(1) {
    my ($self, $c, $page_id) = @_;

    my $page = $c->model('CMS::Page')->find($page_id);
    if ($page) {
        if ($page->status eq 'preview') {
            $page->update({ status => 'published' });
            $c->flash->{status_msg} = "Successfully saved your page";
            $c->res->redirect($c->uri_for($self->action_for('edit_page'), $page_id));
            $c->detach;
        }
    }
}

#-------------------------------------------------------------------------------

sub delete_attachment :Local :Args(1) :AppKitForm {
    my ($self, $c, $attachment_id) = @_;
    
    $self->add_final_crumb($c, 'Delete attachment');
    
    my $attachment = $c->model('CMS::Attachments')->find({id => $attachment_id});
    my $form       = $c->stash->{form};

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('edit_page'), $attachment->page_id));
        $c->detach;
    }
    
    if ($form->submitted_and_valid) {
        $attachment->remove;
        
        $c->flash->{status_msg} = "Attachment deleted";
        $c->res->redirect($c->uri_for($c->controller->action_for('edit_page'), $attachment->page_id));
        $c->detach;
    }
    
    $c->stash->{attachment} = $attachment;
}


#-------------------------------------------------------------------------------

sub edit_attachment :Local :Args(1) :AppKitForm {
    my ($self, $c, $attachment_id) = @_;
    
    $self->add_final_crumb($c, 'Delete attachment');
    
    my $attachment = $c->model('CMS::Attachments')->find({id => $attachment_id});
    my $form       = $c->stash->{form};

    my $defaults = {
        description => $attachment->description,
        priority    => $attachment->priority,
    };
    
    $self->construct_attribute_form($c, 'CMS::AttachmentAttributeDetails');

    my @fields = $c->model('CMS::AttachmentAttributeDetails')->active->all;
    for my $field (@fields)
    {
        my $value = $attachment->attribute($field);
        $defaults->{'global_fields_' . $field->code} = $value;
    }
    
    $form->default_values($defaults);    
    $form->process;

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('edit_page'), $attachment->page_id) . '#tab_attachments');
        $c->detach;
    }
    
    if ($form->submitted_and_valid) {
        $attachment->update({
            description => $form->param_value('description'),
            priority    => $form->param_value('priority'),
        });

        if (my $file = $c->req->upload('file')) {
            $attachment->set_content($file->slurp);
            $attachment->update({
                filename  => $file->basename,
                mime_type => $file->type,
            });
        }
        
        $self->update_attachment_attributes($c, $attachment);

        $c->res->redirect($c->uri_for($c->controller->action_for('edit_page'), $attachment->page_id) . '#tab_attachments');
        $c->detach;        
    }

    $c->stash->{attachment} = $attachment;
}

#-------------------------------------------------------------------------------

sub revisions :Local :Args(1) {
    my ($self, $c, $page_id) = @_;

    my $page = $c->model('CMS::Page')->find($page_id);
    if ($page) {
        $c->stash->{getpage} = $page;
        $c->stash->{drafts}  = $page->page_drafts;
    }
}

#-------------------------------------------------------------------------------

sub construct_attribute_form
{
    my ($self, $c, $model) = @_;

    my $form = $c->stash->{form};
    my @fields = $c->model($model)->active->all;
    if(@fields)
    {
        my $global_fields = $form->get_all_element('global_fields');
        my $no_fields = $form->get_all_element('no_fields');
        for my $field (@fields)
        {
            my $details;
            $details = {
                type => 'Text',
                label => $field->name,
                name => "global_fields_".$field->code,
            };
            given($field->type)
            {
                when(/text/) {
                }
                when(/html/) {
                    $details->{type} = 'Textarea';
                    $details->{attributes} = {
                        class => 'wysiwyg',
                    };
                }
                when(/number/) {
                    $details->{constraints} = { type => 'Number' };
                }
                when(/boolean/) {
                    $details->{type} = 'Checkbox';
                }
                when(/date/) {
                    $details->{attributes} = {
                        autocomplete => 'off',
                        class => 'date_picker',
                    };
                    $details->{size} = 12;
                    $details->{inflators} = {
                        type => 'DateTime',
                        strptime => '%Y-%m-%d 00:00:00',
                        parser => {
                            strptime => '%d/%m/%Y',
                        }
                    };
                    $details->{deflator} = {
                        type => 'Strftime',
                        strftime => '%d/%m/%Y',
                    };
                }
                when(/integer/) {
                    $details->{constraints} = { type => 'Integer' };
                }
                when(/select/) {
                    $details->{type} = 'Select';
                    $details->{empty_first} = 1;
                    $details->{options} = $field->form_options;
                }
            }
            my $element = $global_fields->element($details);
        }
        $global_fields->remove_element($no_fields);
    }
}


#-------------------------------------------------------------------------------

sub update_page_attributes
{
    my ($self, $c, $page) = @_;

    my $form = $c->stash->{form};
    my @fields = $c->model('CMS::PageAttributeDetail')->active->all;
    for my $field (@fields)
    {
        my $value = $form->param_value('global_fields_' . $field->code);
        $page->update_attribute($field, $value);
    }

}


#-------------------------------------------------------------------------------

sub update_attachment_attributes
{
    my ($self, $c, $page) = @_;

    my $form = $c->stash->{form};
    my @fields = $c->model('CMS::AttachmentAttributeDetails')->active->all;
    for my $field (@fields)
    {
        my $value = $form->param_value('global_fields_' . $field->code);
        $page->update_attribute($field, $value);
    }

}

#-------------------------------------------------------------------------------

sub draft_delete :Local :Path('draft/delete') :Args(1) {
    my ($self, $c, $draft_id) = @_;
    my $draft = $c->model('CMS::PageDraft')->find($draft_id);
    my $page;
    if ($draft) {
        $page = $draft->page;
        $draft->page_drafts_contents->delete;
        $draft->delete;
        $c->flash->{status_msg} = "Successfully removed draft";
    }
    else {
        $c->flash->{error_msg} = "Could not find page draft with that id";
        $c->res->redirect($c->uri_for($self->action_for('index')));
        $c->detach;
    }

    $c->res->redirect($c->uri_for($self->action_for('revisions'), $page->id));
    $c->detach;
}

#-------------------------------------------------------------------------------

sub preview :Local :Args(2) {
    my ($self, $c, $page_id, $draft_id) = @_;
    

    if ($c->req->body_params->{cancel}) {
        my $page = $c->model('CMS::Page')->find($c->req->body_params->{page_id});
        my $site = $c->model('CMS::SitesUser')->find({ site_id => $page->site->id, user_id => $c->user->id });
        if ($site) {
            $page->delete;
            $c->flash->{status_msg} = 'Successfully cancelled and removed preview';
            $c->res->redirect($c->uri_for($c->controller('CMS::Pages')->action_for('index')));
            $c->detach;
        }
        else {
            $c->flash->{error_msg} = 'Unable to delete page. Do you have access to it?';
            $c->flash->{status_msg} = 'Successfully published page';
            $c->res->redirect($c->uri_for($c->controller('CMS::Pages')->action_for('index')));
            $c->detach;
        }
    }

    if ($c->req->body_params->{publish}) {
        my $page = $c->model('CMS::Page')->find($c->req->body_params->{page_id});
        my $site = $c->model('CMS::SitesUser')->find({ site_id => $page->site->id, user_id => $c->user->id });
        if ($site) {
            $page->update({ status => 'published' });
            $c->flash->{status_msg} = 'Successfully published page';
            $c->res->redirect($c->uri_for($c->controller('CMS::Pages')->action_for('index')));
            $c->detach;
        }
        else {
            $c->flash->{error_msg} = 'Unable to publish page. Do you have access to it?';
            $c->flash->{status_msg} = 'Successfully published page';
            $c->res->redirect($c->uri_for($c->controller('CMS::Pages')->action_for('index')));
            $c->detach;
        }
    }

    #my $page = $c->model('CMS::PageDraft')->find($page_id);

    my $page = $c->model('CMS::Page')->find($page_id);
    my $site = $page->site;
    my $asset_rs = $site->assets;
    $c->stash->{me}  = $page;
    $c->stash->{cms} = {
        asset => sub {
            if (my $asset = $asset_rs->available->find({id => shift})) {
                return $c->uri_for($self->action_for('_asset'), $asset->id, $asset->filename);
            }
        },
        attachment => sub {
            if (my $attachment = $c->model('CMS::Attachment')->find({id => shift})) {
                return $c->uri_for($self->action_for('_attachment'), $attachment->id, $attachment->filename);
            }
        },
        element => sub {
            if (my $element = $c->model('CMS::Element')->published->find({id => shift})) {
                return $element->content;
            }
        },
        page => sub {
            return $c->model('CMS::Page')->published->find({id => shift});
        },
        pages => sub {
            return $c->model('CMS::Page')->published->attribute_search(@_);
        },
        param => sub {
            return $c->req->param(shift);
        },
        toplevel => sub {
            return $c->model('CMS::Page')->published->toplevel;
        },
        thumbnail => sub {
            return $c->uri_for($self->action_for('_thumbnail'), @_);
        },
    };
    
    if (my $template = $page->template->content) {
        # if the draft_id is 0, then we assume we're using the content from a drafted current page
        # confusing, yeah..
        my $draft;
        my $type;
        my $id;
        if ($draft_id == 0) {
            $draft = $page;
            $type  = 'page';
            $id    = $page->id;
        }
        else {
            $draft = $c->model('CMS::PageDraft')->find($draft_id);
            $type  = 'draft';
            $id    = $draft_id; 
        }
        my $back_url = $c->uri_for($self->action_for('index'));
        $template .= q{
            <style type="text/css">
                .iframe-panel {
                    position: absolute;
                    border-style: none;
                    width: 100%;
                    top: 0 !important;
                    height:30px;
                }

                .cms-preview-content { margin-top: 50px; }
            </style>
        };
        $template .= '<iframe frameborder="0" border="0" cellspacing="0" class="iframe-panel" src="' . $c->uri_for($c->controller('Modules::CMS::Ajax')->action_for('preview_panel'), $type, $id) . '"></iframe>';
        $template = '<div class="cms-preview-content">[% BLOCK content %]' . $draft->content . '[% END %]' . $template . '</div>';
        $c->stash->{template}   = \$template;
        $c->stash->{no_wrapper} = 1;
    }
    
    ##$c->forward($c->view('CMS'));
    $c->forward('AppKitTT');
}

sub _asset :Local :Args(2) {
    my ($self, $c, $asset_id, $filename) = @_;
    
    if (my $asset = $c->model('CMS::Asset')->published->find({id => $asset_id})) {
        $c->response->content_type($asset->mime_type);
        $c->response->body($asset->content);
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

sub _attachment :Local :Args(2) {
    my ($self, $c, $attachment_id, $filename) = @_;
    
    if (my $attachment = $c->model('CMS::Attachment')->find({id => $attachment_id})) {
        $c->response->content_type($attachment->mime_type);
        $c->response->body($attachment->content);
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

sub _thumbnail :Local :Args(2) {
    my ($self, $c, $type, $id) = @_;
    
    given ($type) {
        when ('asset') {
            if (my $asset = $c->model('CMS::Asset')->published->find({id => $id})) {
                $c->stash->{image} = $asset->content;
            }
        }
        when ('attachment') {
            if (my $attachment = $c->model('CMS::Attachment')->find({id => $id})) {
                $c->stash->{image} = $attachment->content;
            }
        }
    }
    
    if ($c->stash->{image}) {
        $c->stash->{x}       = $c->req->param('x') || undef;
        $c->stash->{y}       = $c->req->param('y') || undef;
        $c->stash->{zoom}    = $c->req->param('zoom') || 100;
        $c->stash->{scaling} = $c->req->param('scaling') || 'fill';
        
        unless ($c->stash->{x} || $c->stash->{y}) {
            $c->stash->{y} = 50;
        }
        
        $c->forward($c->view('CMS::Thumbnail'));
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

1;
