package OpusVL::AppKitX::CMS::Controller::CMS::Domains;

use Moose;
use namespace::autoclean;

use URI;

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

    $c->forward('/modules/cms/site_validate');
    my $domains = $c->model('CMS::MasterDomain')
        ->search({ site => $c->stash->{site}->id });
    
    $c->stash->{domains} = $domains;
    $c->stash->{section} = 'Domains';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Domains',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}


#-------------------------------------------------------------------------------

sub domain_root :Chained('/') :PathPart('domain') :CaptureArgs(1) {
    my ($self, $c, $site_id) = @_;
    my $domains = $c->model('CMS::MasterDomain')
        ->search({ site => $site_id });

    my $site   = $c->model('CMS::Site')
        ->find($site_id);

    unless ($site) {
        $c->flash->{error_msg} = "No such site";
        $c->res->redirect($c->uri_for($c->controller('Sites')->action_for('index')));
        $c->detach;
    }

    $c->stash->{domains} = $domains;
    $c->stash->{site}   = $site;
}

#-------------------------------------------------------------------------------

sub master_domain_root :Chained('/') :PathPart('domain') :CaptureArgs(2) {
    my ($self, $c, $site_id, $domain) = @_;
    my $site   = $c->model('CMS::Site')
        ->find($site_id);

    $domain = $c->model('CMS::MasterDomain')
        ->find({ domain => $domain, site => $site_id });


    unless ($domain) {
        $c->flash->{error_msg} = "No such domain";
        $c->res->redirect($c->uri_for($c->controller('Domains')->action_for('manage'), [ $site_id ]));
        $c->detach;
    }

    $c->stash->{domain} = $domain;
    $c->stash->{site}   = $site;
}

#-------------------------------------------------------------------------------

sub manage :Local :Args() :NavigationName('Domains') {
    my ($self, $c, $site_id) = @_;
    my $domains = $c->stash->{domains};

    $c->session->{site} = $c->stash->{site};
    if ($site_id) {
        my $site = $c->model('CMS::Site')->find($site_id);
        if ($site) {
            delete $c->session->{selected_domain};
            $c->session->{site} = $site;
            $c->res->redirect($c->uri_for($self->action_for('manage')));
            $c->detach;
        }
    }

    if ($domains->count > 0) {
        $c->stash->{master_domains} = [ $domains->all ];
    }
    else {
        if ($c->stash->{selected_domain}) {
            delete $c->session->{selected_domain};
            $c->res->redirect($c->req->uri);
            $c->detach;
        }
    }
}

#-------------------------------------------------------------------------------

sub edit :Chained('master_domain_root') :Args(0) :NavigationName('Edit Domain') :AppKitForm {
    my ($self, $c) = @_;
    my $form       = $c->stash->{form};
    my $site       = $c->stash->{site};
    my $domain     = $c->stash->{domain};

    my $redirect_domain   = $domain->redirect_domains->first ?
        $domain->redirect_domains->first->domain : undef;

    my $alternate_domains;
    if ($domain->alternate_domains->count > 0) {
        for my $adom ($domain->alternate_domains->all) {
            my $prot = $adom->secure ? "https://" : "http://";
            $alternate_domains .= $prot . $adom->domain . "\n";
        }
    }

    $form->default_values({
        master_domain     => $domain->domain,
        redirect_domain   => $redirect_domain,
        alternate_domains => $alternate_domains,
    });

    if ($form->submitted_and_valid) {
        $domain->update({ domain => $form->param('master_domain') });

        # update the redirect?
        if ($c->req->body_params->{redirect_domain}) {
            $domain->redirect_domains->find_or_create({
                domain          => $form->param('redirect_domain'),
                master_domain   => $domain->id,
                status          => 'active',
            });
        }
        else {
            $domain->redirect_domains->delete;
        }

        # now the alternate domains
        my @adom_errors;
        if ($c->req->body_params->{alternate_domains}) {
            $domain->alternate_domains->delete;
            if ($form->param('alternate_domains') !~ /^\s*?$/) {
                my @adomains = split("\n", $form->param('alternate_domains'));
                for my $adom (@adomains) {
                    # without the protocol on the uri, the URI module 
                    # will spaz out and not be able to get the host and port
                    if ($adom !~ /http(s)?:\/\//) {
                        push @adom_errors, $adom;
                        next;
                    }
                    $adom = URI->new($adom);
                    my ($host, $port) = ($adom->host, $adom->port);
                    my $secure        = $adom->secure;

                    $domain->alternate_domains->create({
                        domain          => $host,
                        master_domain   => $domain->id,
                        port            => $port,
                        secure          => $secure||0,
                    });
                }
            }
        }
        else {
            $domain->alternate_domains->delete;
        }

        if (scalar(@adom_errors) > 0) {
            $c->flash->{error_msg} = "Alternate domains not added because http(s):// is missing: " .
                join(', ', @adom_errors);
        }

        $c->flash->{status_msg} = "Successfully updated domain";
        $c->res->redirect($c->uri_for($self->action_for('edit'), [ $site->id, $form->param('master_domain') ]));
        $c->detach;
    }

    if ($c->req->body_params->{cancel}) {
        $c->res->redirect($c->uri_for($self->action_for('manage')));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

sub add_master :Chained('domain_root') :Args(0) :PathPart('add/master') :NavigationName('Add Master') :AppKitForm {
    my ($self, $c)  = @_;
    my $form        = $c->stash->{form};
    my $site        = $c->stash->{site};
    my $domain_rs   = $c->model('CMS::MasterDomain');

    if ($form->submitted_and_valid) {
        my $exists = $domain_rs->find({ domain => $form->param('master_domain') });
        if ($exists) {
            $c->flash->{error_msg} = "The domain " . $form->param('master_domain') . " already exists";
            $c->res->redirect($c->req->uri);
            $c->detach;
        }
        else {
            $domain_rs->create({
                site   => $site->id,
                domain => $form->param('master_domain'),
            });

            $c->flash->{status_msg} = "Successfully added master domain for " . $site->name;
            $c->res->redirect($c->uri_for($self->action_for('manage')));
            $c->detach;
        }
    }

    if ($c->req->body_params->{cancel}) {
        $c->res->redirect($c->uri_for($self->action_for('manage')));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

sub select_domain :Chained('domain_root') :Args(1) {
    my ($self, $c, $domain_name) = @_;
    my $site = $c->stash->{site};
    my $domain = $c->model('CMS::MasterDomain')
        ->find({ site => $site->id, domain => $domain_name });

    if ($domain) {
        if ($domain->site->sites_users->find({ user_id => $c->user->id })) {
            $c->session->{selected_domain} = $domain;
            $c->flash->{status_msg} = "Selected " . $domain->domain . " as your current domain";
            $c->res->redirect($c->uri_for($self->action_for('manage')));
            $c->detach;
        }
        else {
            $c->flash->{error_msg} = "Unathorised access to that domain";
            $c->res->redirect($c->uri_for($self->action_for('manage')));
            $c->detach;
        }
    }
}

#-------------------------------------------------------------------------------

sub unselect_domain :Chained('domain_root') :Args(1) {
    my ($self, $c, $domain_name) = @_;
    my $site = $c->stash->{site};
    delete $c->session->{selected_domain};
    $c->res->redirect($c->uri_for($self->action_for('manage')));
    $c->detach;
}
1;
