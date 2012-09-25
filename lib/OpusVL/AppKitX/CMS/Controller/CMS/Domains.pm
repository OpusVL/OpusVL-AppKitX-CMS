package OpusVL::AppKitX::CMS::Controller::CMS::Domains;

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

sub index :Path :Args(0) :NavigationHome :NavigationName('Domains') {
    my ($self, $c) = @_;
}

#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;

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

sub manage :Chained('domain_root') :Args(0) :NavigationName('Domains') {
    my ($self, $c) = @_;
    my $domains = $c->stash->{domains};

    if ($domains->count > 0) {
        $c->stash->{master_domains} = [ $domains->all ];
    }
}

#-------------------------------------------------------------------------------

sub edit :Chained('master_domain_root') :Args(0) :NavigationName('Edit Domain') :AppKitForm {
    my ($self, $c) = @_;
    my $form       = $c->stash->{form};
    my $site       = $c->stash->{site};
    my $domain     = $c->stash->{domain};

    $form->default_values({
        master_domain   => $domain->domain,
    });
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
            $c->res->redirect($c->uri_for($self->action_for('manage'), [ $site->id ] ));
            $c->detach;
        }
    }

    if ($c->req->body_params->{cancel}) {
        $c->res->redirect($c->uri_for($self->action_for('manage'), [ $site->id ]));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

1;
