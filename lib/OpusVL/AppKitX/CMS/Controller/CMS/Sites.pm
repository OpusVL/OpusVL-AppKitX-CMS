package OpusVL::AppKitX::CMS::Controller::CMS::Sites;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    appkit_name                 => 'CMS',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_css                  => [ '/static/css/cms.css' ],
    #appkit_js                     => ['/static/js/cms.js', '/static/js/nicEdit.js', '/static/js/src/addElement/addElement.js'],
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

sub index :Path :Args(0) :NavigationHome :NavigationName('Sites') {
    my ($self, $c) = @_;
    my $sites = $c->stash->{all_sites};
    #my $sites = $c->user->sites_users;
    if ($sites) {
        if (! $c->stash->{site}) { $c->session->{site} = $sites->[0]->site }
    }
}


#-------------------------------------------------------------------------------

sub add :Local :Args(0) :NavigationName('Add Site') :AppKitForm {
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

sub site_root :Chained('') :PathPart('site') :CaptureArgs(1) {
    my ($self, $c, $site_id) = @_;
    $c->stash->{site} = $c->model('CMS::Site')->find($site_id);
    unless ($c->stash->{site}) {
        $c->flash->{error_msg} = "Could not locate site";
        $c->res->redirect($c->uri_for($self->action_for('index')));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

sub edit :Chained('site_root') :PathPart('edit') :Args(0) :NavigationName('Edit Site') :AppKitForm {
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

sub manage_attributes :Local :Path('attributes/manage') :Args(0) :AppKitForm {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};
    my $form = $c->stash->{form};
    $site    = $c->model('CMS::Site')->find($site->id);
    my $attrs = $site->site_attributes;
    if ($attrs->count > 0) {
        $c->stash->{site_attributes} = [ $attrs->all ];
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

sub delete_attribute :Local :Path('attribute/delete') :Args(1) {
    my ($self, $c, $attr_id) = @_;
    my $site = $c->model('CMS::Site')->find($c->stash->{site}->id);

    if (my $attr = $site->site_attributes->find($attr_id)) {
        my $attr_name = $attr->code;
        $attr->delete;
        $c->flash(status_msg => "Successfully removed attribute $attr_name");
        $c->res->redirect($c->uri_for($self->action_for('manage_attributes')));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

1;