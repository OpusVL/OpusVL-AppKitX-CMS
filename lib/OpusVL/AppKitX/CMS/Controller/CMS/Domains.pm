package OpusVL::AppKitX::CMS::Controller::CMS::Domains;

use Moose;
use namespace::autoclean;

use URI;

BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    #appkit_name                 => 'CMS',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_css                  => [ '/static/css/bootstrap.css' ],
    appkit_js                     => ['/static/js/cms.js', '/static/js/bootstrap.js', '/static/js/nicEdit.js', '/static/js/src/addElement/addElement.js'],
    appkit_method_group         => 'Content Management',
    appkit_method_group_order   => 1,
    appkit_shared_module        => 'CMS',
);

#-------------------------------------------------------------------------------

sub base :Chained('/') :PathPart('domains') :CaptureArgs(0) {
    my ($self, $c) = @_;
}

sub domains :Chained('base') :PathPart('domain') :CaptureArgs(2) {
    my ($self, $c, $site_id, $domain) = @_;
    $c->forward('Modules::CMS::Sites', 'base', [ $site_id ]);

    my $site = $c->stash->{site};
    $domain = $c->model('CMS::MasterDomain')
        ->find({ domain => $domain, site => $site->id });


    unless ($domain) {
        $c->flash->{error_msg} = "No such domain";
        $c->res->redirect($c->uri_for($c->controller('Modules::CMS::Domains')->action_for('manage'), [ $site_id ]));
        $c->detach;
    }

    $c->stash(
        domain => $domain,
        site   => $site,
    );
}

#-------------------------------------------------------------------------------

sub index :Chained('base') :Args(0) {
    my ($self, $c) = @_;
}

#-------------------------------------------------------------------------------

sub manage :Chained('/modules/cms/sites/base') :PathPart('domains/manage') :Args(0) {
    my ($self, $c) = @_;
    my $site       = $c->stash->{site};
    my $domains    = $site->master_domains;

    if ($domains->count > 0) {
        $c->stash->{master_domains} = [ $domains->all ];
    }
}

#-------------------------------------------------------------------------------

sub edit :Chained('domains') :Args(0) :PathPart('edit') :AppKitForm {
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
        $c->res->redirect($c->uri_for($self->action_for('manage'), [ $site->id ]));
        $c->detach;
    }

    if ($c->req->body_params->{cancel}) {
        $c->res->redirect($c->uri_for($self->action_for('manage'), [ $site->id ]));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

sub add_master :Chained('/modules/cms/sites/base') :Args(0) :PathPart('add/master') :AppKitForm {
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
            $c->res->redirect($c->uri_for($self->action_for('manage'), [ $site->id ]));
            $c->detach;
        }
    }

    if ($c->req->body_params->{cancel}) {
        $c->res->redirect($c->uri_for($self->action_for('manage'), [ $site->id ]));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

sub delete_domain :Chained('domains') :PathPart('delete') :Args(0) {
    my ($self, $c) = @_;
    my $domain = $c->stash->{domain};
    my $site   = $c->stash->{site};

    $c->flash(status_msg => "Removed " . $domain->domain);
    $domain->delete;
    $c->res->redirect($c->uri_for($self->action_for('manage'), [ $site->id ]));
    $c->detach;
}

1;
