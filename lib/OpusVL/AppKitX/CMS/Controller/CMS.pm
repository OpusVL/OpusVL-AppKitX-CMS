package OpusVL::AppKitX::CMS::Controller::CMS;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';

__PACKAGE__->config
(
    appkit_name                 => 'CMS',
    # appkit_icon                 => 'static/images/flagA.jpg',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_js                     => ['/static/js/cms.js'],
    # appkit_method_group         => 'Extension A',
    # appkit_method_group_order   => 2,
    # appkit_shared_module        => 'ExtensionA',
);

sub auto :Private {
    my ($self, $c) = @_;
 
    if (! $c->user) {
        $c->res->redirect('/logout');
        $c->detach;
    }

    1;
}

sub home
    :Path
    :Args(0)
    :NavigationHome
    :AppKitFeature('CMS Home')
{
    my ($self, $c) = @_;
}

sub portlet_recent_pages : PortletName('Most Recent Pages') :AppKitFeature('Portlets') {
    my ($self, $c) = @_;
    my $sites = $c->model('CMS::SitesUser')->search({ user_id => $c->user->id });

    # FIXME: This is super inefficient. Learn how to properly join or prefetch the tables required.
    my $pages = $c->model('CMS::Page')->search({
        created => {
            -between => [
                DateTime->now->subtract(days => 5),
                DateTime->now(),
            ],
        },
        status => 'published',
    }, {
        rows     => 5,
        order_by => { -desc => [ 'created' ] },
    });

    my @user_pages;
    for my $page ($pages->all) {
        if ($page->site->sites_users->find({ user_id => $c->user->id  })) {
            push @user_pages, $page;
        }
    }

    $c->stash(cms_recent_pages => \@user_pages);
}

sub portlet_current_site : PortletName('Sites') :AppKitFeature('Portlets') {
    my ($self, $c) = @_;
    my $sites      = $c->model('CMS::SitesUser')->search({ user_id => $c->user->id });
    
    if ($sites->count > 0) {
        my $active_sites = $sites->search_related('site', { status => 'active' });
        $c->stash(
            sites        => [ $sites->all ],
            active_sites => $active_sites->count,
        );
    }
}

sub redirect_url :Local :Args() :AppKitFeature('Redirect URL') {
    my ($self, $c, $controller, $action, @args) = @_;
    $controller = ucfirst($controller);
    if (@args) {
        $c->res->redirect($c->uri_for($c->controller("Modules::CMS::${controller}")->action_for($action),
            @args));
        $c->detach;
    }
    else {
        $c->res->redirect($c->uri_for($c->controller("Modules::CMS::${controller}")->action_for($action)));
        $c->detach;
    }
}

sub site_validate :Action :Args(0) :AppKitFeature('Validate Site') {
    my ($self, $c) = @_;
    my $site   = $c->stash->{site};
    if (! $site) {
        $c->flash->{error_msg} = "Please select a site before proceeding";
        $c->res->redirect($c->uri_for($c->controller('Sites')->action_for('index')));
        $c->detach;
    }

    1;
}

=head1 NAME

OpusVL::AppKitX::CMS::Controller:CMS - 

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

=head1 AUTHOR

=head1 COPYRIGHT and LICENSE

Copyright (C) 2012 OpusVL

This software is licensed according to the "IP Assignment Schedule" provided with the development project.

=cut

