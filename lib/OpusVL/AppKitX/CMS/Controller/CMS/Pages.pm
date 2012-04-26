package OpusVL::AppKitX::CMS::Controller::CMS::Pages;

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
    
    $c->stash->{section} = 'Pages';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Pages',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationHome :NavigationName('Pages') {
    my ($self, $c) = @_;
    
    $c->stash->{pages} = [$c->model('CMS::Pages')->all];
}


#-------------------------------------------------------------------------------

sub new_page :Local :Args(0) :AppKitForm {
    my ($self, $c) = @_;

    $self->add_final_crumb($c, "New page");

    my $form = $c->stash->{form};
    
    $form->get_all_element({name=>'template'})->options(
        [map {[$_->id, $_->name]} $c->model('CMS::Templates')->all]
    );
    $form->get_all_element({name=>'parent'})->options(
        [map {[$_->id, $_->breadcrumb . " - " . $_->url]} $c->model('CMS::Pages')->all]
    );

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
    
    $self->add_final_crumb($c, "Edit page");

    my $page = $c->model('CMS::Pages')->find({id => $page_id});
    my $form = $c->stash->{form};
        
    $form->get_all_element({name=>'template'})->options(
        [map {[$_->id, $_->name]} $c->model('CMS::Templates')->all]
    );
    $form->get_all_element({name=>'parent'})->options(
        [map {[$_->id, $_->breadcrumb . " - " . $_->url]} $c->model('CMS::Pages')->all]
    );
    $form->get_all_element({name=>'new_tag'})->options(
        [map {[$_->id, $_->group->name . " - " . $_->name]} $c->model('CMS::Tags')->all]
    );
    
    my $tags_fieldset = $form->get_all_element({name=>'page_tags'});
    if (my @page_tags = $page->search_related('pagetags')) {
        foreach my $tag_link (@page_tags) {
            my $tag = $tag_link->tag;
            $tags_fieldset->element({
                type     => 'Multi',
                label    => $tag->group->name . ' - ' . $tag->name,
                elements => [
                    {
                        type  => 'Checkbox',
                        name  => 'delete_tag_' . $tag_link->id,
                        label => 'Delete',
                    }
                ]
            });
        }
    } else {
        $tags_fieldset->element({
            type    => 'Block',
            tag     => 'p',
            content => 'No tags have been added to this page',
        });
    }
    
    $form->default_values({
        url         => $page->url,
        description => $page->description,
        title       => $page->title,
        h1          => $page->h1,
        breadcrumb  => $page->breadcrumb,
        template    => $page->template_id,
        parent      => $page->parent_id,
        content     => $page->content,
        priority    => $page->priority,
    });

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
        
        foreach my $param (keys %{$c->req->params}) {
            if ($param =~ /delete_tag_(\d+)/) {
                if (my $tag = $page->search_related('pagetags', {id => $1})) {
                    $tag->delete;
                }
            }
        }
        
        if (my $tag_id = $form->param_value('new_tag')) {
            # FIXME: validate that we are allowed to add this tag
            $page->create_related('pagetags', {tag_id => $tag_id});
        }
        
        $c->flash->{status_msg} = "Your changes have been saved";
        $c->res->redirect($c->req->uri);
        $c->detach;
    }
    
    $c->stash->{page} = $page;
}

1;