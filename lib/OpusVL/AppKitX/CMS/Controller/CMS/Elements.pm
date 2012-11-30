package OpusVL::AppKitX::CMS::Controller::CMS::Elements;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    appkit_name                 => 'Elements',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_css                  => [qw</static/js/redactor/redactor.css /static/css/bootstrap.css /static/js/codemirror/codemirror.css /static/js/codemirror/util/dialog.css>],
    appkit_js                   => [qw</static/js/bootstrap.js /static/js/redactor/redactor.js /static/js/beautify/beautify.js /static/js/beautify/beautify-html.js /static/js/beautify/beautify-css.js /static/js/codemirror/codemirror.js /static/js/codemirror/mode/xml/xml.js /static/js/codemirror/mode/javascript/javascript.js /static/js/codemirror/mode/css/css.js /static/js/codemirror/mode/htmlmixed/htmlmixed.js /static/js/codemirror/util/search.js /static/js/codemirror/util/searchcursor.js /static/js/codemirror/util/dialog.js>],
    appkit_method_group         => 'Content Management',
    appkit_method_group_order   => 1,
    appkit_shared_module        => 'CMS',
    #appkit_css                  => ['/static/modules/cms/cms.css'],
);

#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;
    
    $c->stash->{section} = 'Elements';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Elements',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}

#-------------------------------------------------------------------------------

sub base :Chained('/') :PathPart('elements') :CaptureArgs(0) :AppKitFeature('Elements - Read Access') {
    my ($self, $c) = @_;
}

sub elements :Chained('base') :PathPart('element') :CaptureArgs(2) :AppKitFeature('Elements - Read Access') {
    my ($self, $c, $site_id, $element_id) = @_;
    $c->forward('/modules/cms/sites/base', [ $site_id ]);

    my $element = $c->model('CMS::Element')->find({ site => $site_id, id => $element_id });

    unless ($element) {
        $c->flash(error_msg => "No such element");
        $c->res->redirect($c->uri_for($self->action_for('index'), [ $site_id ]));
        $c->detach;
    }
    
    $c->stash( element => $element );
}

#-------------------------------------------------------------------------------

sub index :Chained('/modules/cms/sites/base') :PathPart('element/list') :Args(0) :AppKitFeature('Elements - Read Access') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};

    $c->stash->{elements} = [$c->model('CMS::Element')
        ->search({
            -or => [
                site    => $site->id,
                global  => 1,
            ]
        })
        ->published->all];
}

#-------------------------------------------------------------------------------

sub new_element :Chained('/modules/cms/sites/base') :PathPart('element/new') :Args(0) :AppKitForm :AppKitFeature('Elements - Write Access') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};

    $self->add_final_crumb($c, "New element");
    
    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $element = $c->model('CMS::Element')->create({
            name   => $form->param_value('name'),
            site   => $site->id,
            global => $form->param_value('global')||0,
        });
        
        $element->set_content($form->param_value('content'));
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $site->id ]));
    }
}


#-------------------------------------------------------------------------------

sub edit_element :Chained('elements') :PathPart('edit') :Args(0) :AppKitForm :AppKitFeature('Elements - Write Access') {
    my ($self, $c) = @_;
    my $element = $c->stash->{element};
    my $site    = $c->stash->{site};

    my $restricted_row = $c->model('CMS::Parameter')->find({ parameter => 'Restricted' });

    if ($restricted_row) {
        if ($c->user->users_parameters->find({ parameter_id => $restricted_row->id })) {
            unless ($c->model('CMS::ElementUser')->find({ element_id => $element->id, user_id => $c->user->id })) {
                $c->detach('/access_denied');
            }
        }
    }

    $self->add_final_crumb($c, "Edit element");
    
    my $form    = $c->stash->{form};
    $c->stash( attributes => [ $element->element_attributes->all ] );
    
    $form->default_values({
        name    => $element->name,
        content => $element->content,
        global  => $element->global
    });
    
    $form->process;
    
    if ($form->submitted_and_valid) {
        #if ($form->param_value('name') ne $element->name) {
            $element->update({name => $form->param_value('name'),global => $form->param_value('global')||0});
        #}

        if ($form->param_value('content_edit') ne $element->content) {
            $element->set_content($form->param_value('content_edit'));
        }
        
        $c->flash(status_msg => "Updated element " . $element->name);
        $c->res->redirect($c->req->uri);
        $c->detach;
    }

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($self->action_for('index'), [ $site->id ]));
        $c->detach;
    }

    # if a new attribute was specified
    if (my $attr = $c->req->body_params->{attr_name}) {
        $attr = lc $attr;           # make the attribute name lowercase
        $attr =~ s/\s/_/g;          # replace whitespace with underscores
        $attr =~ s/[^\w\d\s]//g;  # remove any punctuation
        $element->create_related('element_attributes', { code => $attr })
            if not $element->element_attributes->find({ code => $attr });

        $c->flash( status_msg => "Created attribute $attr" );
        $c->res->redirect($c->req->uri . "#element-attributes");
        $c->detach;
    }
}


#-------------------------------------------------------------------------------

sub delete_element :Chained('elements') :PathPart('delete') :Args(0) :AppKitForm :AppKitFeature('Elements - Write Access') {
    my ($self, $c, $element_id) = @_;
    my $element = $c->stash->{element};
    my $site    = $c->stash->{site};

    $self->add_final_crumb($c, "Delete element");
    
    my $form    = $c->stash->{form};

    if ($form->submitted_and_valid) {
        $element->remove;
        
        $c->flash(status_msg => "Element deleted");
        $c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $site->id ]));
        $c->detach;
    }
}


#-------------------------------------------------------------------------------

sub delete_element_attribute :Chained('elements') :PathPart('delete/element/attribute') :Args(1) :AppKitFeature('Elements - Write Access') {
    my ($self, $c, $attr_id) = @_;
    my $element = $c->stash->{element};
    my $site    = $c->stash->{site};

    if (my $attr = $element->element_attributes->find( $attr_id )) {
        $attr->delete;
        $c->flash(status_msg => "Successfully delete attribute");
        $c->res->redirect($c->uri_for($self->action_for('edit_element'), [ $site->id, $element->id ]));
        $c->detach;
    }
}

#-------------------------------------------------------------------------------

1;
