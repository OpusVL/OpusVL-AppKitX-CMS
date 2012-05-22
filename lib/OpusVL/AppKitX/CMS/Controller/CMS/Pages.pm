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
    # appkit_method_group         => 'Extension A',
    # appkit_method_group_order   => 2,
    appkit_shared_module        => 'CMS',
    #appkit_css                  => ['/static/modules/cms/cms.css'],
);

 
#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;

    $c->stash->{section} = 'Pages';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Pages',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationHome :NavigationName('Pages') {
    my ($self, $c) = @_;
    
    $c->stash->{pages} = [ $c->model('CMS::Pages')->published->search({},{order_by => {'-asc' => 'url'}}) ];
}


#-------------------------------------------------------------------------------

sub new_page :Local :Args(0) :AppKitForm {
    my ($self, $c) = @_;

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }
    
    $c->stash->{element_rs} = $c->model('CMS::Elements');
    $self->add_final_crumb($c, "New page");

    my $form = $c->stash->{form};
    
    $form->get_all_element({name=>'template'})->options(
        [map {[$_->id, $_->name]} $c->model('CMS::Templates')->all]
    );
    $form->get_all_element({name=>'parent'})->options(
        [map {[$_->id, $_->breadcrumb . " - " . $_->url]} $c->model('CMS::Pages')->all]
    );
    
    $form->default_values({
        parent => $c->req->param('parent_id'),
    });

    $form->process;
    
    if ($form->submitted_and_valid) {
        my $url = $form->param_value('url');
        unless ($url =~ m!^/!) {$url = "/$url"}
        
        my $page = $c->model('CMS::Pages')->create({
            url         => $url,
            description => $form->param_value('description'),
            title       => $form->param_value('title'),
            h1          => $form->param_value('h1'),
            priority    => $form->param_value('priority') || undef,
            breadcrumb  => $form->param_value('breadcrumb'),
            template_id => $form->param_value('template') || undef,
            parent_id   => $form->param_value('parent') || undef,
        });
        
        $page->set_content($form->param_value('content'));

        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

sub edit_page :Local :Args(1) :AppKitForm {
    my ($self, $c, $page_id) = @_;
    
    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }
    
    $self->add_final_crumb($c, "Edit page");

    my $page = $c->model('CMS::Pages')->find({id => $page_id});
    my $form = $c->stash->{form};
        
    $form->get_all_element({name=>'template'})->options(
        [map {[$_->id, $_->name]} $c->model('CMS::Templates')->all]
    );
    $form->get_all_element({name=>'parent'})->options(
        [map {[$_->id, $_->breadcrumb . " - " . $_->url]} $c->model('CMS::Pages')->all]
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
    
    $self->construct_attribute_form($c, 'CMS::PageAttributeDetails');

    my @fields = $c->model('CMS::PageAttributeDetails')->active->all;
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
        
        $page->update({
            url         => $url,
            description => $form->param_value('description'),
            title       => $form->param_value('title'),
            h1          => $form->param_value('h1'),
            priority    => $form->param_value('priority') || undef,
            breadcrumb  => $form->param_value('breadcrumb'),
            template_id => $form->param_value('template') || undef,
            parent_id   => $form->param_value('parent') || undef,
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
    my @fields = $c->model('CMS::PageAttributeDetails')->active->all;
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
1;
