package OpusVL::AppKitX::CMS::Controller::CMS::Pages;

use 5.010;
use Moose;
use Scalar::Util qw<blessed looks_like_number>;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    appkit_name                 => 'Pages',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_css                  => [qw< /static/js/redactor/redactor.css /static/css/bootstrap.css >],
    appkit_js                   => [qw< /static/js/bootstrap.js /static/js/redactor/redactor.js /static/js/beautify/beautify.js /static/js/beautify/beautify-html.js /static/js/beautify/beautify-css.js /static/js/ace/ace.js>],
    appkit_method_group         => 'Content Management',
    appkit_method_group_order   => 1,
    appkit_shared_module        => 'CMS',
);

 
#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;

    $c->stash->{section} = 'Pages';
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Pages',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };

    1;
}


#-------------------------------------------------------------------------------

sub base :Chained('/') :PathPart('pages') :CaptureArgs(0) :AppKitFeature('Pages - Read Access') {
    my ($self, $c) = @_;
}

sub pages :Chained('base') :PathPart('page') :CaptureArgs(2) :AppKitFeature('Pages - Read Access') {
    my ($self, $c, $site_id, $page_id) = @_;
    $c->forward('/modules/cms/sites/base', [ $site_id ]);

    my $page = $c->model('CMS::Page')->find({ site => $site_id, id => $page_id });

    unless ($page) {
        $c->flash(error_msg => "No such page");
        $c->res->redirect($c->uri_for($self->action_for('index'), [ $site_id ]));
        $c->detach;
    }
    
    $c->stash( page => $page );
}

sub page_contents :Chained('base') :PathPart('page') :CaptureArgs(2) :AppKitFeature('Pages - Read Access') {
    my ($self, $c, $site_id, $page_id) = @_;
    $c->forward('/modules/cms/sites/base', [ $site_id ]);

    my $page = $c->model('CMS::Page')->find($page_id);
    my $page_content = $page->get_page_content;

    unless ($page_content) { #and $page_content->page->site->id == $site_id) {
        $c->flash(error_msg => "No such page");
        $c->res->redirect($c->uri_for($self->action_for('index'), [ $site_id ]));
        $c->detach;
    }
    
    $c->stash(
        page_content => $page_content,
        page         => $page,
    );
}

#-------------------------------------------------------------------------------

sub index :Chained('/modules/cms/sites/base') :PathPart('pages/list') :Args(0) :AppKitFeature('Pages - Read Access') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};

    my $pages = [ $c->model('CMS::Page')
        ->search({
            site => $site->id,
            status => 'published',
            blog   => 0,
            parent_id => undef,
        }, { order_by => { '-asc' => 'url' }})->all ];

    $c->stash( pages => $pages );

    if ($c->req->body_params->{edit_page}) {
        if (my $page = $site->pages->search({ -and => [ status => 'published', url => $c->req->body_params->{edit_page} ] })->first) {
            $c->res->redirect($c->uri_for($self->action_for('edit_page'), [ $site->id, $page->id ]));
            $c->detach;
        }
    }
}

sub page_list :Chained('pages') :PathPart('page/list') :Args(0) :AppKitFeature('Pages - Read Access') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};
    my $page = $c->stash->{page};

    $c->stash( kids => [ $page->children()->all ] || [] );
}

#-------------------------------------------------------------------------------

sub orphan_pages :Chained('/modules/cms/sites/base') :PathPart('pages/orphaned') :Args(0) :AppKitFeature('Pages - Read Access') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};

    my @orphans;
    my $non_published_pages = $site->pages->search({ status => 'deleted' });
    if ($non_published_pages->count > 0) {
        for my $page ($non_published_pages->all) {
            my $alive_children = $page->children()->search({ status => 'published' });
            for my $child ($alive_children->all) {
                unshift @orphans, $child;
            }
        }

        if (scalar(@orphans) > 0) { $c->stash(orphans => \@orphans); }
    }
}

#-------------------------------------------------------------------------------

sub blogs :Chained('/modules/cms/sites/base') :PathPart('blogs') :Args(0) :AppKitFeature('Blogs') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};
    $c->stash(blogs => [ $c->model('CMS::Page')->search({ status => 'published', site => $site->id, blog => 1 })->all ]);
}

sub blog_posts :Chained('pages') :PathPart('blog/posts') :Args(0) :AppKitFeature('Blogs') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};
    my $blog = $c->stash->{page};

    $c->stash(posts => [ $blog->children()->all ]);
}

#-------------------------------------------------------------------------------

sub new_page :Chained('/modules/cms/sites/base') :PathPart('page/new') :Args(0) :AppKitForm :AppKitFeature('Pages - Write Access') {
    my ($self, $c) = @_;
    my $site       = $c->stash->{site};

    my $templates = $c->model('CMS::Template')
        ->search({ -or => [ site => $site->id, global => 1 ]  });
    if ($templates->count < 1) {
        $c->flash->{error_msg} = "You may want to setup a template before you create a page";
        $c->res->redirect($c->uri_for($c->controller('Modules::CMS::Templates')->action_for('new_template'), [ $site->id ]));
        $c->detach;
    }

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $site->id ]));
        $c->detach;
    }
    
    $c->stash->{element_rs} = $c->model('CMS::Element');
    $self->add_final_crumb($c, "New page");

    my $form = $c->stash->{form};
    
    $form->get_all_element({name=>'template'})->options(
        [map {[$_->id, $_->name . " (" . $_->site->name . ")"]} $c->model('CMS::Template')
            ->search({ -or => [ site => $site->id, global => 1 ] })]
    );
    $form->get_all_element({name=>'parent'})->options(
        [map {[$_->id, $_->breadcrumb . " - " . $_->url]} $c->model('CMS::Page')->search({ site => $site->id })->published->all]
    );
    $form->get_all_element({ name => 'markup_type' })->options(
        [['Standard', 'Standard'], ['Markdown', 'Markdown']]
    );

    $form->default_values({
        site => $site->id,
        content_type => 'text/html',
    });
    # This part was throwing out undefined value as a HASH reference errors
    # before validating the $c->req->body_params
    if ($c->req->query_params->{parent_id}) {
        my $parent_id = $c->req->param('parent_id');
        if (my $parent = $c->model('CMS::Page')->find($parent_id)) {
            $form->default_values({
                parent => $parent_id,
                url    => $parent->url eq '/' ? '/' : $parent->url . "/",
            });

            $c->stash->{is_a_post} = 1 if $parent->blog;
        }
    }

    if ($c->req->query_params and $c->req->query_params->{type} eq 'blog') {
        $c->stash->{type} = 'Blog';
        $form->default_values({
            content => q{
[% page = cms.param('page') %]
[% UNLESS page %][% page = 1 %][% END %]
[% articles = me.children({},{'sort' = 'newest', 'rows' = 5, 'page' = page, 'rs_only' = 1}) %]

[% WHILE (article = articles.next) %]
    <div style="padding-bottom:20px;" class="">
        <h3>[% article.title %]</h3>
        <strong>[% article.description %]</strong>
        <p>[% article.content.substr(0, 300).replace('\<div\>', '').replace('\<\/div\>', '') | none %]...</p>

        <a style="font-weight:bold" href="[% article.url %]">Read more</a>
    </div>
[% END %]

<div id="pager">
[% pager = articles.pager %]
[% IF pager.previous_page %]
    <div id="pager_prev">
        <a href="[% me.url %]?page=[% pager.previous_page %]">&laquo; Previous page</a>
    </div>
[% END %]
[% IF pager.next_page %]
    <div id="pager_next">
        <a href="[% me.url %]?page=[% pager.next_page %]">Next page &raquo;</a>
   </div>
[% END %]
</div>
            },
        });
    }

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
            markup_type => $form->param_value('markup_type') || 'Standard',
            site        => $site->id,
            status      => $status,
            blog        => $c->req->query_params && $c->req->param('type') eq 'blog' ? 1 : 0,
            content_type => $form->param_value('content_type') || 'text/html',
        });
        
        $page->set_content($form->param_value('content'));

        if ($status eq 'preview') {
            $c->res->redirect($c->uri_for($c->controller->action_for('preview'), [$site->id, $page->id]) . "?panel=1");
            $c->detach;
        }

        if (my $parent = $form->param_value('parent')) {
            if (my $blog = $c->model('CMS::Page')->search({ id => $parent, blog => 1 })->first) {
                $c->res->redirect($c->uri_for($self->action_for('blog_posts'), [ $site->id, $blog->id ]));
                $c->detach;
            }
        }

        $c->res->redirect($c->uri_for($c->controller->action_for('edit_page'), [ $site->id, $page->id ]));
    }
}


#-------------------------------------------------------------------------------

sub clone_page :Chained('pages') :PathPart('clone') :Args(0) :AppKitFeature('Pages - Write Access') {
    my ($self, $c) = @_;
    my $page = $c->stash->{page};
    my $site = $c->stash->{site};

    if (my $new_page = $page->copy({ status => 'preview', url => $page->url . "_clone" })) {
        my $page_users = $c->model('CMS::PageUser');
        $new_page->set_content($page->content);
        $page_users->find_or_create({
            page_id => $new_page->id,
            user_id => $c->user->id,
        });

        $c->flash(status_msg => "You are now viewing the clone of " . $page->title);
        $c->res->redirect($c->uri_for($self->action_for('edit_page'), [ $site->id, $new_page->id ]));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

sub edit_page :Chained('pages') :PathPart('edit') :Args(0) :AppKitForm :AppKitFeature('Pages - Write Access') {
    my ($self, $c) = @_;
    my $page = $c->stash->{page};
    my $site = $c->stash->{site};

    my $restricted_row = $c->model('CMS::Parameter')->find({ parameter => 'Restricted' });

    if ($restricted_row) {
        if ($c->user->users_parameters->find({ parameter_id => $restricted_row->id })) {
            unless ($c->model('CMS::PageUser')->find({ page_id => $page->id, user_id => $c->user->id })) {
                $c->detach('/access_denied');
            }
        }
    }

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $site->id ]));
        $c->detach;
    }
    
    $self->add_final_crumb($c, "Edit page");

    #FIXME: my $page_users = [ $site->page_users->page_us ];
    my $site_users = [ $site->sites_users->all ];
    my $form = $c->stash->{form};
    
    $c->stash(
        site_users => $site_users,
        page_users => [ $page->page_users->all ],
    );

    my $templates = $c->model('CMS::Template')->search({
        -or => [
            site    => $site->id,
            global  => 1,
        ],
    });
    
    $form->get_all_element({name=>'template'})->options(
        [map {[$_->id, $_->name . " (" . $_->site->name . ")"]} $templates->all ]
    );
    $form->get_all_element({name=>'parent'})->options(
        [map {[$_->id, $_->breadcrumb . " - " . $_->url]} $site->pages->published->all ]
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
        note_changes => $page->note_changes,
        site         => $site->id,
        content_type => $page->content_type,
        markup_type  => $page->markup_type,
    };
 
    $DB::single = 1;   
    $self->construct_attribute_form($c, { type => 'page', site_id => $site->id });

    my @fields = $site->page_attribute_details->active->all;
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
            if ($page->content ne $form->param_value('content')) {
                my $copy = $page->get_page_content->copy({ status => 'preview', body => $form->param_value('content'), created => DateTime->now() });
                if ($copy) {
                    $c->res->redirect($c->uri_for($self->action_for('preview'), [ $site->id, $page->id ]) . "?panel=1&content=" . $copy->id);
                    $c->detach;
                }
            }
            else {
                $c->res->redirect($c->uri_for($self->action_for('preview'), [ $site->id, $page->id ]) . "?panel=1");
                $c->detach;
            }
        }

        my $new_content = $page->create_related('page_contents', {
            body => $form->param_value('content'),
            created_by => $c->user->id,
        });
        #die $form->param_value('description');
        $page->update({
            url         => $url,
            description => $form->param_value('description'),
            title       => $form->param_value('title'),
            h1          => $form->param_value('h1'),
            priority    => $form->param_value('priority') || undef,
            breadcrumb  => $form->param_value('breadcrumb'),
            template_id => $form->param_value('template') || undef,
            parent_id   => $form->param_value('parent') || undef,
            content_type => $form->param_value('content_type') || 'text/html',
            site        => $site->id,
            note_changes => $form->param_value('note_changes'),
            status      => 'published',
            markup_type => $defaults->{markup_type},
        });
        
        if (my $file  = $c->req->upload('new_att_file')) {
            my $attachment = $page->create_related('attachments', {
                slug        => $form->param_value('slug')||'',
                filename    => $file->basename,
                mime_type   => $file->type,
                description => $form->param_value('new_att_desc'),
                priority    => $form->param_value('new_att_priority') || undef,
            });
            
            if ($attachment->slug eq '') { $attachment->update({ slug => $attachment->id }); }
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
                        $page->create_related('aliases', {url => $alias_url});
                    }
                }
            }
        }
        
        if (my $alias_url = $form->param_value('new_alias_url')) {
            unless ($alias_url =~ m!^/!) {$alias_url = "/$url"}
            $page->create_related('aliases', {url => $alias_url});
        }

        $self->update_page_attributes($c, $page, $site);

        if ($c->req->body_params->{allow_users}) {
            my $user_rs = $c->model('CMS::User');
            my $users = $c->req->body_params->{allow_users};
            $users    = [ $users ] if ref($users) ne 'ARRAY';
            for my $user (@$users) {
                $user = $user_rs->find($user);
                if ($user) {
                    $page->page_users->find_or_create({
                        page_id => $page->id,
                        user_id => $user->id,
                    });
                }
            }
        }

        $c->flash->{status_msg} = "Your changes have been saved";
        $c->res->redirect($c->uri_for($self->action_for('edit_page'), [ $site->id, $page->id ]));
        $c->detach;
    }
    
    $c->stash(
        page => $page,
    );
}


#-------------------------------------------------------------------------------

sub delete_page :Chained('pages') :PathPart('delete') :Args(0) :AppKitForm :AppKitFeature('Pages - Write Access') {
    my ($self, $c) = @_;

    my $page = $c->stash->{page};
    my $site = $c->stash->{site};
    my $form = $c->stash->{form};
    
    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $site->id ]));
        $c->detach;
    }
    
    $self->add_final_crumb($c, "Delete page");
    
    if ($form->submitted_and_valid) {
        my $parent = $page->parent;
        if ($parent && $parent->blog) {
            my $parent = $page->parent;
            if (my $blog = $c->model('CMS::Page')->find({ id => $parent->id, type => 'blog' })) {
                $page->remove;
                $c->res->redirect($c->uri_for($self->action_for('blog_posts'), [ $site->id, $blog->id ]));
                $c->detach;
            }
        }
        my $action = $page->blog ? 'blogs' : 'index';
        $page->remove;
        
        $c->flash->{status_msg} = "Page deleted";
        $c->res->redirect($c->uri_for($c->controller->action_for($action), [ $site->id ]));
        $c->detach;
    }
}


#-------------------------------------------------------------------------------

sub save_preview :Chained('page_contents') :Args(0) :AppKitFeature('Pages - Write Access') {
    my ($self, $c)   = @_;
    my $site         = $c->stash->{site};
    my $page_content = $c->stash->{page_content};
    my $page         = $c->stash->{page};
    # There's a bug where if you save a preview of an edited page
    # you end up with duplicate published versions.. let's try to patch that 
    # up briefly here, for now
    #if (my $is_page = $c->model('CMS::Page')->find({ url => $page->url, status => 'published' })) {
    #    $is_page->update({ status => 'draft' });
    #}
    
    #if ($page->status eq 'preview') {
        $page_content->update({ status => 'Published' });
        $page->update({ status => 'published' });

        if ($c->req->query_params && $c->req->query_params->{content} ne '') {
            if (my $new_content = $c->model('CMS::PageContent')->find( $c->req->param('content'))) {
                $page_content->update({ status => 'draft' });
                $new_content->update({ status => 'Published' });
            }
        }
        $c->flash(status_msg => "Successfully saved your page");
        $c->res->redirect($c->uri_for($self->action_for('edit_page'), [ $site->id, $page_content->page->id ]));
        $c->detach;
    #}
}

#-------------------------------------------------------------------------------

sub cancel_preview :Chained('pages') :Args(0) :AppKitFeature('Pages - Read Access') {
    my ($self, $c, $page_id) = @_;

    my $site = $c->stash->{site};
    my $page = $c->stash->{page};

    if ($page->status eq 'preview') {
        $c->flash(status_msg => "Cancelled preview");
        $c->res->redirect($c->uri_for($self->action_for('edit_page'), [ $site->id, $page->id ]));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

sub delete_attachment :Local :Args(1) :AppKitForm :AppKitFeature('Pages - Write Access') {
    my ($self, $c, $attachment_id) = @_;
    
    $self->add_final_crumb($c, 'Delete attachment');
    
    my $attachment = $c->model('CMS::Attachment')->find({id => $attachment_id});
    my $form       = $c->stash->{form};
    my $page = $c->model('CMS::Page')->find($attachment->page_id);

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('edit_page'), [ $page->site->id, $attachment->page_id ]));
        $c->detach;
    }
    
    if ($form->submitted_and_valid) {
        $attachment->remove;
        
        $c->flash->{status_msg} = "Attachment deleted";
        $c->res->redirect($c->uri_for($c->controller->action_for('edit_page'), [ $page->site->id, $attachment->page_id ]));
        $c->detach;
    }
    
    $c->stash->{attachment} = $attachment;
}


#-------------------------------------------------------------------------------

sub edit_attachment :Local :Args(1) :AppKitForm :AppKitFeature('Pages - Write Access') {
    my ($self, $c, $attachment_id) = @_;
    
    $self->add_final_crumb($c, 'Delete attachment');
    
    my $attachment = $c->model('CMS::Attachment')->find({id => $attachment_id});
    my $form       = $c->stash->{form};
    my $page       = $c->model('CMS::Page')->find( $attachment->page_id );
    my $defaults = {
        slug        => $attachment->slug,
        description => $attachment->description,
        priority    => $attachment->priority,
    };
    
    $self->construct_attribute_form($c, { type => 'attachment', site_id => $page->site->id });

    my @fields = $page->site->attachment_attribute_details->active->all;
    for my $field (@fields)
    {
        my $value = $attachment->attribute($field);
        $defaults->{'global_fields_' . $field->code} = $value;
    }
    
    $form->default_values($defaults);    
    $form->process;

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('edit_page'), [ $page->site->id, $attachment->page_id ]) . '#tab_attachments');
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
        
        $self->update_attachment_attributes($c, $attachment, $page->site);

        $c->res->redirect($c->uri_for($c->controller->action_for('edit_page'), [ $page->site->id, $attachment->page_id ]) . '#tab_attachments');
        $c->detach;        
    }

    $c->stash(
        attachment => $attachment,
        site       => $page->site,
    );
}

#-------------------------------------------------------------------------------

sub revisions :Chained('pages') :Args(0) :AppKitFeature('Pages - Read Access') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};
    my $page = $c->stash->{page};

    $c->stash->{pages}  = $page->search_related('page_contents', undef, {
        rows     => 15,
        page     => $c->req->query_params->{page} || 1,
        order_by => { -desc => 'created' }
    });
    
}

#-------------------------------------------------------------------------------

sub restore :Chained('page_contents') :Args(0) :AppKitFeature('Pages - Write Access') {
    my ($self, $c) = @_;
    my $site         = $c->stash->{site};
    my $page_content = $c->stash->{page_content};
    my $page         = $c->stash->{page};

    if ($c->req->query_params && $c->req->query_params->{content} ne '') {
        if (my $con = $c->model('CMS::PageContent')->find({ page_id => $page->id, id => $c->req->param('content') })) {
            $page_content->update({ status => 'draft' });
            $page_content = $con;
        }
    }

    $c->flash(status_msg => "Successfully restored revision from " . $page_content->created->dmy . ' ' . $page_content->created->hms);
    $page_content->update({ status => 'Published' }) if $page_content->status ne 'Published';
    $page_content->update({ created => DateTime->now() });
    $c->res->redirect($c->uri_for($self->action_for('revisions'), [ $site->id, $page_content->page->id ]));
}

#-------------------------------------------------------------------------------

sub construct_attribute_form
{
    my ($self, $c, $args) = @_;
    my $model = $args->{type} eq 'page' ?
        $c->model('CMS::PageAttributeDetail') : $c->model('CMS::AttachmentAttributeDetail');

    # Argh, I need to fix this in the schema!
    my $form = $c->stash->{form};
        my @fields = $model->search({ site_id => $args->{site_id} })->active->all;
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
    my ($self, $c, $page, $site) = @_;

    my $form = $c->stash->{form};
    my @fields = $site->page_attribute_details->active->all;
    for my $field (@fields)
    {
        my $value = $form->param_value('global_fields_' . $field->code);
        $page->update_attribute($site->id, $field, $value);
    }

}


#-------------------------------------------------------------------------------

sub update_attachment_attributes
{
    my ($self, $c, $attachment, $site) = @_;

    my $form = $c->stash->{form};
    my @fields = $site->attachment_attribute_details->active->all;
    for my $field (@fields)
    {
        my $value = $form->param_value('global_fields_' . $field->code);
        $attachment->update_attribute($site->id, $field, $value);
    }

}

#-------------------------------------------------------------------------------

sub draft_delete :Local :Path('draft/delete') :Args(1) :AppKitFeature('Pages - Write Access') {
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

sub preview :Chained('page_contents') :Args(0) :AppKitFeature('Pages - Read Access') {
    my ($self, $c)   = @_;
    my $site         = $c->stash->{site};
    my $page_content = $c->stash->{page_content};
    my $page         = $c->stash->{page};

    if ($c->req->query_params && $c->req->query_params->{content}) {
        if (my $con = $c->model('CMS::PageContent')->find( $c->req->param('content') )) {
            $page_content = $con;
        }
    }

    if ($c->req->body_params->{cancel}) {
        my $page = $c->model('CMS::Page')->find($c->req->body_params->{page_id});
        my $site = $c->model('CMS::SitesUser')->find({ site_id => $page->site->id, user_id => $c->user->id });
        if ($site) {
            $page->delete;
            $c->flash->{status_msg} = 'Successfully cancelled and removed preview';
            $c->res->redirect($c->uri_for($c->controller('CMS::Pages')->action_for('index'), [ $site->id ]));
            $c->detach;
        }
        else {
            $c->flash->{error_msg} = 'Unable to delete page. Do you have access to it?';
            $c->flash->{status_msg} = 'Successfully published page';
            $c->res->redirect($c->uri_for($c->controller('CMS::Pages')->action_for('index'), [ $site->id ]));
            $c->detach;
        }
    }

    if ($c->req->body_params->{publish}) {
        my $page = $c->model('CMS::PageContent')->find($c->req->body_params->{page_id});
        if ($page) {
            $page->update({ status => 'published' });
            $c->flash->{status_msg} = 'Successfully published page';
            $c->res->redirect($c->uri_for($c->controller('CMS::Pages')->action_for('index'), [ $site->id ]));
            $c->detach;
        }
        else {
            $c->flash->{error_msg} = 'Unable to publish page. Do you have access to it?';
            $c->flash->{status_msg} = 'Successfully published page';
            $c->res->redirect($c->uri_for($c->controller('CMS::Pages')->action_for('index'), [ $site->id ]));
            $c->detach;
        }
    }

    my $asset_rs   = $c->model('CMS::Asset');
    my $element_rs = $c->model('CMS::Element');
    $c->stash->{me}  = $page;
    $c->stash->{cms} = {
        asset => sub {
                my $id = shift;
                if (looks_like_number $id) {
                    if (my $asset = $c->model('CMS::Asset')->available($site->id)->find({slug => $id})) {
                        return $c->uri_for($self->action_for('_asset'), $asset->id, $asset->filename);
                    }
                }
                else {
                    # not a number? then we may be looking for a logo!
                    if ($id eq 'logo') {
                        if (my $logo = $site->assets->available($site->id)->find({ description => 'Logo' })) {
                            return $c->uri_for($self->action_for('_asset'), $logo->id, $logo->filename);
                        }
                        else {
                            if ($logo = $c->model('CMS::Asset')->available($site->id)->find({ global => 1, description => 'Logo' })) {
                                return $c->uri_for($self->action_for('_asset'), $logo->id, $logo->filename);
                            }
                        }
                    }
                    # normal
                    else {
                        if (my $asset = $c->model('CMS::Asset')->available($site->id)->find({ slug => $id })) {
                            return $c->uri_for($self->action_for('_asset'), $asset->id, $asset->filename);
                        }
                    }
                }
            },
            attachment => sub {
                if (my $attachment = $c->model('CMS::Attachment')->find({slug => shift})) {
                    return $c->uri_for($self->action_for('_attachment'), $attachment->id, $attachment->filename);
                }
            },
            element => sub {
                my ($id, $attrs) = @_;
                if ($attrs) {
                    foreach my $attr (%$attrs) {
                        $c->stash->{me}->{$attr} = $attrs->{$attr};
                    }
                }
                if (my $element = $c->model('CMS::Element')->available($site->id)->find({slug => $id})) {
                    return $element->content;
                }
            },
            site_attr => sub {
                my $code = shift;
                if (my $attr = $site->site_attributes->find({ code => $code })) {
                    return $attr->value;
                }
            },
            page => sub {
                return $site->pages->published->find({id => shift});
            },
            pages => sub {
                return $site->pages->published->attribute_search($site->id, @_);
            },
            param => sub {
                return $c->req->param(shift);
            },
            toplevel => sub {
                return $site->pages->published->toplevel;
            },
            thumbnail => sub {
                return $c->uri_for($self->action_for('_thumbnail'), @_);
            },
            form      => sub {
                my $name = shift;
                return $site->forms->find({ name => $name });
            },
    };

    # load any plugins
    my @plugins = $c->model('CMS::Plugin')->search({ status => 'active' })->all;
    if (scalar @plugins > 0) {
      {
        no strict 'refs';
        foreach my $plugin (@plugins) {
          my $code = $plugin->code;
          $code =~ s/[^[:ascii:]]//g;
          $c->stash->{cms}->{plugin}->{ $plugin->action } = sub { eval($code) };
        }
      }
    }

    if (my $template = $page->template->content) {
        if ($c->req->query_params->{panel}) {
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
            $template .= '<iframe frameborder="0" border="0" cellspacing="0" class="iframe-panel" src="' . $c->uri_for($c->controller('Modules::CMS::Ajax')->action_for('preview_panel'), $page_content->id) . '?content=' . $c->req->param('content') . '"></iframe>';
        }
        $template = '<div class="cms-preview-content">[% BLOCK content %]' . $page_content->body . '[% END %]' . $template . '</div>';
        $c->stash->{template}   = \$template;
        $c->stash->{no_wrapper} = 1;
    }
    
    ##$c->forward($c->view('CMS'));
    $c->view('CMS::Preview');
}

sub _asset :Local :Args(2) {
    my ($self, $c, $asset_id, $filename) = @_;
    if ($filename) {
        if ($asset_id eq 'use') {
            if (my $asset = $c->model('CMS::Asset')->published->search({ slug => $filename })->first) {
                $asset_id = $asset->id;
            }
            else {
                $c->res->status(404);
                $c->res->body("Not found");
            }
        }

        if (my $asset = $c->model('CMS::Asset')->published->search({ slug => $asset_id })->first) {
            $c->response->content_type($asset->mime_type);
            $c->response->body($asset->content);
            $c->detach;
        }
        elsif ($asset = $c->model('CMS::Asset')->published->search({id => $asset_id})->first) {
            $c->response->content_type($asset->mime_type);
            $c->response->body($asset->content);
            $c->detach;
        } else {
            $c->response->status(404);
            $c->response->body("Not found");
        }
    }
}

sub _attachment :Path('/_attachment') :Args(2) {
    my ($self, $c, $attachment_id, $filename) = @_;
    
    if (my $attachment = $c->model('CMS::Attachment')->find({id => $attachment_id})) {
        $c->response->content_type($attachment->mime_type);
        $c->response->body($attachment->content);
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

sub _thumbnail :Path('/_thumbnail') :Args(2) {
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
