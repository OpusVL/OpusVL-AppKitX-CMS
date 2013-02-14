package OpusVL::AppKitX::CMS::Controller::CMS::Sites;

use 5.010;
use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    appkit_name                 => 'Sites',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_css                  => [ '/static/css/bootstrap.css' ],
    appkit_js                     => ['/static/js/bootstrap.js'],
    appkit_method_group         => 'Content Management',
    appkit_method_group_order   => 1,
    appkit_shared_module        => 'CMS',
    #appkit_css                  => ['/static/modules/cms/cms.css'],
);

 
#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Sites',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationName('Sites') :AppKitFeature('Site - Read Access') {
    my ($self, $c) = @_;

    my @sites = $c->model('CMS::SitesUser')->sites($c->user->id);
    $c->stash->{sites} = \@sites;
}

#-------------------------------------------------------------------------------

sub add :Local :Args(0) :AppKitForm :AppKitFeature('Site - Write Access'){
    my ($self, $c) = @_;
    my $form       = $c->stash->{form};
    my $users      = [ $c->model('CMS::User')->all ];
    my %user_list  = map { $_->username => $_->id } @{$users};
    $self->add_final_crumb($c, "Add Site");
    
    # We need to use a 'GET' method to 'PUT' values in an element
    # Why FormFu? Why??!
    $form->get_all_element ({ name => 'user_list' })->options([
        map {[ $_->id => $_->username ]} @{$users}
    ]);
    
    if ($form->submitted_and_valid) {
        my $sites_users = $c->model('CMS::SitesUser');
        my $sites       = $c->model('CMS::Site');
        my $site        = $sites->create({ name => $form->param('name') });
        if ($site) {
            my $users_to_add = $c->req->body_params->{user_list};
            $users_to_add = [ $users_to_add ]
                if ref($users_to_add) ne 'ARRAY';

            for my $user_id (@{$users_to_add}) {
                $sites_users->create({
                    site_id => $site->id,
                    user_id => $user_id,
                });
            }

            my $site_attr  = $site->site_attributes;
            my $asset_attr = $site->asset_attributes;
            my $page_attr  = $site->page_attribute_details;
            my $att_attr   = $site->attachment_attribute_details;
            for my $attr ($c->model('CMS::DefaultAttribute')->all) {
                given ($attr->type) {
                    when ('site') {
                        $site_attr->find_or_create({
                            site_id => $site->id,
                            code    => $attr->code,
                            value   => $attr->value||'',
                            name    => $attr->name,
                            super   => 1,
                        });
                    }
                    #when ('asset') {
                    #    my $new_attr = $asset_attr->find_or_create({
                    #        site_id => $site->id,
                    #        code    => $attr->code,
                    #        name    => $attr->name,
                    #        type    => $attr->field_type,
                    #    });

                    #    if ($new_attr) {
                    #        if ($attr->field_type eq 'select') {
                    #            # the select field has values
                    #            if ($attr->values->count > 0) {
                    #                for my $value ($attr->values->all) {
                    #                    $new_attr->field_values->find_or_create({
                    #                        field_id => $new_attr->id,
                    #                        value    => $value->value
                    #                    });
                    #                }
                    #            }
                    #        }
                    #    }
                    #}
                    when ('page') {
                        my $new_attr = $page_attr->find_or_create({
                            site_id => $site->id,
                            name    => $attr->name,
                            code    => $attr->code,
                            type    => $attr->field_type,
                        });

                        if ($new_attr) {
                            if ($attr->field_type eq 'select') {
                                # the select field has values
                                if ($attr->values->count > 0) {
                                    for my $value ($attr->values->all) {
                                        $new_attr->field_values->find_or_create({
                                            field_id => $new_attr->id,
                                            value    => $value->value
                                        });
                                    }
                                }
                            }
                        }
                    }
                    when ('attachment') {
                        my $new_attr = $att_attr->find_or_create({                                                                                                         
                            site_id => $site->id,                                                                                                                           
                            name    => $attr->name,                                                                                                                         
                            code    => $attr->code,                                                                                                                         
                            type    => $attr->field_type,                                                                                                                   
                        });                                                                                                                                                 
                                                                                                                                                                            
                        if ($new_attr) {                                                                                                                                    
                            if ($attr->field_type eq 'select') {                                                                                                            
                                # the select field has values                                                                                                               
                                if ($attr->values->count > 0) {                                                                                                             
                                    for my $value ($attr->values->all) {                                                                                                    
                                        $new_attr->field_values->find_or_create({                                                                                           
                                            field_id => $new_attr->id,                                                                                                      
                                            value    => $value->value                                                                                                       
                                        });                                                                                                                                 
                                    }                                                                                                                                       
                                }                                                                                                                                           
                            }                                                                                                                                               
                        }
                    }
                } # /given
            } # /for
            
            my $many = scalar(@{$users_to_add}) > 1 ? 'users' : 'user'; 
            $c->flash->{status_msg} = "Successfully added ${many} to site " . $form->param('name');
            $c->res->redirect($c->uri_for($self->action_for('index')));
            $c->detach;
        }
        else {
            $c->flash->{error_msg} = "There was a problem adding the site to the database";
            $c->res->redirect($c->uri_for($self->action_for('add')));
            $c->detach;
        }
    }
    
    if ($c->req->body_params->{cancel}) {
        $c->res->redirect($c->uri_for($self->action_for('index')));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

sub base :Chained('/') :PathPart('site') :CaptureArgs(1) :AppKitFeature('Site - Read Access') {
    my ($self, $c, $site_id) = @_;
    my $site = $c->model('CMS::Site')->search({ id => $site_id, status => 'active' })->first;
    unless ($site) {
        $c->flash->{error_msg} = "Could not locate site";
        $c->res->redirect($c->uri_for($self->action_for('index')));
        $c->detach;
    }

    #push @{ $c->stash->{breadcrumbs} }, {
    #    name    => $site->name,
    #    url     => $c->uri_for( $c->controller('Modules::CMS::Sites')->action_for('index'), [ $site->id ])
    #};

    if (! $c->model('CMS::SitesUser')->find({ site_id => $site_id, user_id => $c->user->id })) {
        $c->flash(error_msg => "Sorry, but you don't have access to this site");
        $c->res->redirect($c->uri_for($self->action_for('index')));
        $c->detach;
    }

    $c->stash(
        site        => $site,
        elements    => [ $c->model('CMS::Element')->available($site_id)->all ],
        assets      => [ $c->model('CMS::Asset')->available($site_id)->all ],
        site_attributes  => [ $site->site_attributes->all ],
        pages       => [ $site->pages->published->all ],
        attachments => [ $site->pages->search_related('attachments', { 'attachments.status' => 'published' })->all ],
    );
}

#-------------------------------------------------------------------------------

sub delete_site :Local :Args(1) :AppKitFeature('Site - Write Access') {
    my ($self, $c, $site_id) = @_;
    
    if (my $site = $c->model('CMS::Site')->find($site_id)) {
        if ($c->model('CMS::SitesUser')->find({ user_id => $c->user->id, site_id => $site_id })) {
            $site->update({ status => 'deleted' });
            $site->master_domains->delete;
            $c->flash(status_msg => 'Successfully removed ' . $site->name);
        }
        else {
            $c->flash(error_msg => 'You do not have access to ' . $site->name);
        }
    }

    
    $c->res->redirect($c->uri_for($self->action_for('index')));
    $c->detach;
}

#-------------------------------------------------------------------------------

sub edit :Chained('base') :PathPart('edit') :Args(0) :AppKitForm :AppKitFeature('Site - Write Access') {
    my ($self, $c)  = @_;
    my $form        = $c->stash->{form};
    my $site        = $c->stash->{site};
    my $sites_users = [ $site->sites_users->all ];

    $c->session->{site} = $site;
    $c->stash->{sites_users} = $sites_users;

    # populate default values
    $form->default_values({ name => $site->name });
    $form->get_all_element ({ name => 'user_list' })->options([
        map {[ $_->id => $_->username ]} $c->model('CMS::User')->all
    ]);

    if ($form->submitted_and_valid) {
        my $sites_users_rs = $c->model('CMS::SitesUser');
        my $site_users = $sites_users_rs
            ->search({ site_id => $site->id });

        $site_users->delete();

        my $users_to_add = $c->req->body_params->{user_list};
        $users_to_add = [ $users_to_add ]
            if ref($users_to_add) ne 'ARRAY';

        for my $user_id (@{$users_to_add}) {
            $sites_users_rs->create({
                site_id => $site->id,
                user_id => $user_id,
            });
        }

        $site->update({ name => $form->param('name') });

        my $many = scalar(@{$users_to_add}) > 1 ? 'users' : 'user'; 
        $c->flash->{status_msg} = "Successfully updated ${many} to site " . $form->param('name');
        $c->res->redirect($c->req->uri);
        $c->detach;

    }

    if ($c->req->body_params->{cancel}) {
        $c->res->redirect($c->uri_for($self->action_for('index')));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

sub manage_attributes :Chained('base') :PathPart('attributes/manage') :Args(0) :AppKitForm :AppKitFeature('Site - Write Access') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};
    my $form = $c->stash->{form};
    $site    = $c->model('CMS::Site')->find($site->id);
    my $attrs = $site->site_attributes;
    if ($attrs->count > 0) {
        $c->stash->{site_attributes} = [ $attrs->search(undef, { order_by => { -asc => 'name' } })->all ];
    }

    if ($c->req->body_params->{save_attributes}) {
        foreach my $param (keys %{$c->req->body_params}) {
            if ($param =~ /^attribute_id_(\d+)$/) {
                my $id = $1;
                if (my $get_attr = $attrs->find($id)) {
                    $get_attr->update({ value => $c->req->body_params->{$param} });
                }
            }
        }

        $c->flash(status_msg => "Updated attributes");
        $c->res->redirect($c->req->uri);
        $c->detach;
    }

    if ($form->submitted_and_valid) {
        my ($attr_name, $attr_value) = (
            $form->param_value('attr_name'),
            $form->param_value('attr_value'),
        );

        my $attr_code   = lc $attr_name;           # make the attribute name lowercase
        $attr_code      =~ s/\s/_/g;               # replace whitespace with underscores
        $attr_code      =~ s/[^\w\d\s]//g;         # remove any punctuation

        my $new_attr = $site->create_related('site_attributes', {
            name  => $attr_name,
            code  => $attr_code,
            value => $attr_value,
        });

        if ($new_attr) {
            $c->flash(status_msg => "Successfully created new attribute $attr_name");
            $c->res->redirect($c->req->uri);
            $c->detach;
        }
    }
}

#-------------------------------------------------------------------------------

sub delete_attribute :Chained('base') :PathPart('attribute/delete') :Args(1) :AppKitFeature('Site - Write Access') {
    my ($self, $c, $attr_id) = @_;
    my $site = $c->stash->{site};

    if (my $attr = $site->site_attributes->find($attr_id)) {
        my $attr_name = $attr->code;
        $attr->delete;
        $c->flash(status_msg => "Successfully removed attribute $attr_name");
        $c->res->redirect($c->uri_for($self->action_for('manage_attributes'), [ $site->id ]));
        $c->detach;
    }
}

1;
