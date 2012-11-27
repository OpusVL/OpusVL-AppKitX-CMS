package OpusVL::AppKitX::CMS::Controller::CMS::Plugins;

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
    appkit_css                  => [qw</static/js/redactor/redactor.css /static/css/bootstrap.css /static/js/codemirror/codemirror.css>],
    appkit_js                   => [qw</static/js/bootstrap.js /static/js/redactor/redactor.js /static/js/beautify/beautify.js /static/js/beautify/beautify-html.js /static/js/beautify/beautify-css.js /static/js/codemirror/codemirror.js /static/js/codemirror/mode/xml/xml.js /static/js/codemirror/mode/javascript/javascript.js /static/js/codemirror/mode/css/css.js /static/js/codemirror/mode/htmlmixed/htmlmixed.js>],
    appkit_method_group         => 'Content Management',
    appkit_method_group_order   => 1,
    appkit_shared_module        => 'CMS',
);

 
#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;

    $c->stash->{section} = 'Plugins';
    #$c->forward('/modules/cms/site_validate');
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Plugins',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };

    1;
}

#-------------------------------------------------------------------------------

sub base :Chained('/') :PathPart('plugin') :CaptureArgs(1) {
    my ($self, $c, $plugin_id) = @_;
    my $plugin = $c->model('CMS::Plugin')->find($plugin_id);

    unless ($plugin) {
        $c->flash(error_msg => 'Plugin could not be found');
        $c->res->redirect($c->uri_for($self->action_for('index')));
        $c->detach;
    }

    $c->stash( plugin => $plugin );
}

#-------------------------------------------------------------------------------

sub index :Local :Args(0) :NavigationName('Plugins') {
    my ($self, $c) = @_;
    my $plugins = $c->model('CMS::Plugin');
    if ($plugins->count > 0) {
        $c->stash(plugins => [ $plugins->all ] );
    }
}

#-------------------------------------------------------------------------------

sub enable_plugin :Chained('base') :PathPart('enable') :Args(0) {
    my ($self, $c) = @_;
    my $plugin = $c->stash->{plugin};
    $plugin->update({ status => 'active' });
    $c->flash( status_msg => 'Activated plugin' );
    $c->res->redirect($c->uri_for($self->action_for('index')));
    $c->detach;
}

sub disable_plugin :Chained('base') :PathPart('disable') :Args(0) {
    my ($self, $c) = @_;
    my $plugin = $c->stash->{plugin};
    $plugin->update({ status => 'disabled' });
    $c->flash( status_msg => 'Disabled plugin' );
    $c->res->redirect($c->uri_for($self->action_for('index')));
    $c->detach;
}

#-------------------------------------------------------------------------------

sub new_plugin :Local :PathPart('plugin/new') :Args(0) :AppKitForm {
    my ($self, $c) = @_;
    my $form       = $c->stash->{form};

    if ($form->submitted_and_valid) {
        my $plugin = $c->model('CMS::Plugin')->create({
            author      => $c->user->name,
            action      => $form->param_value('action'),
            name        => $form->param_value('name'),
            code        => $form->param_value('code'),
            description => $form->param_value('description'),
        });

        $c->flash(status_msg => 'Successfully created your plugin');
        $c->res->redirect($c->uri_for($self->action_for('index')));
        $c->detach;
    }
}

1;