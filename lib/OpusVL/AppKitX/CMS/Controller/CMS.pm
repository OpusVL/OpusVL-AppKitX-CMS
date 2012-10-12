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
    appkit_js                     => ['/static/js/nicEdit.js', '/static/js/cms.js'],
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

    my $sites = $c->model('CMS::SitesUser')
        ->search({ user_id => $c->user->id });

    if ($sites) {
        $c->stash->{all_sites} = [ $sites->all ];
        $DB::single = 1;

        $c->stash->{selected_domain} = $c->session->{selected_domain}
            if $c->session->{selected_domain};

        # we need to clear out old session data to avoid lurking bugs
        # or fix AppKit's menu system so we can actually use Chained actions
        if ($c->session->{site}) {
            if ($c->model('CMS::Site')->find($c->session->{site}->id)) {
                $c->stash->{site} = $c->session->{site}
            }
            else {
                delete $c->session->{site};
                delete $c->session->{selected_domain};
                delete $c->stash->{site};
            }
        }
    }

    1;
        
    #push @{ $c->stash->{breadcrumbs} }, {
    #    name    => 'CMS',
    #    url     => $c->uri_for( $c->controller('Modules::CMS::Pages')->action_for('index'))
    #};
}

sub home
    :Path
    :Args(0)
    :NavigationHome
    :AppKitFeature('CMS Home')
{
    my ($self, $c) = @_;
}

sub portlet_recent_pages : PortletName('Most Recent Pages') {
    my ($self, $c) = @_;
    my $pages = $c->model('CMS::Page')->search_rs({
        created => {
            -between => [
                DateTime->now(),
                DateTime->now()->subtract(days => 5),
            ]
        }
    }, {
        rows        => 5,
        order_by    => { -desc => [ 'created' ] },
    });

    $c->stash->{cms_recent_pages} = [ $pages->all ];
}

sub portlet_current_site : PortletName('Selected Site') {
    my ($self, $c) = @_;
    $c->stash->{sites} = [$c->model('CMS::Site')->all]; # FIXME: Needs to use sites_users
}

sub redirect_url :Local :Args() {
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

sub forget_site :Local :Args(0) {
    my ($self, $c) = @_;
    delete $c->stash->{site};
    delete $c->session->{site};
    delete $c->session->{selected_domain};
    $c->res->redirect($c->uri_for($c->controller('Sites')->action_for('index')));
    $c->detach;
}

sub site_validate :Action :Args(0) {
    my ($self, $c) = @_;
    my $site   = $c->stash->{site};
    #my $domain = $c->stash->{selected_domain};
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

