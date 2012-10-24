package OpusVL::AppKitX::CMS::Controller::CMS::Elements;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    appkit_name                 => 'CMS',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_css                  => [qw</static/css/bootstrap.css /static/css/jwysiwyg/jquery.wysiwyg.css /static/css/jwysiwyg/jquery.wysiwyg.modal.css>],
    appkit_js                   => [qw< /static/js/bootstrap.js /static/js/wysiwyg/jquery.wysiwyg.js /static/js/wysiwyg/controls/wysiwyg.colorpicker.js /static/js/wysiwyg/controls/wysiwyg.cssWrap.js /static/js/wysiwyg/controls/wysiwyg.image.js /static/js/wysiwyg/controls/wysiwyg.link.js /static/js/wysiwyg/controls/wysiwyg.table.js /static/js/cms.js /static/js/bootstrap-button.js /static/js/bootstrap-transition.js /static/js/bootstrap-modal.js>],
    #appkit_js                     => ['/static/js/nicEdit.js', '/static/js/cms.js'],
    appkit_method_group         => 'Content Management',
    appkit_method_group_order   => 1,
    appkit_shared_module        => 'CMS',
    #appkit_css                  => ['/static/modules/cms/cms.css'],
);

 
#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;

    $c->forward('/modules/cms/site_validate');

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }
    
    $c->stash->{section} = 'Elements';
 
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Elements',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationName('Elements') {
    my ($self, $c) = @_;
    
    $c->stash->{elements} = [$c->model('CMS::Element')
        ->search({
            -or => [
                site    => $c->stash->{site}->id,
                global  => 1,
            ]
        })
        ->published->all];
}

#-------------------------------------------------------------------------------

sub new_element :Local :Args(0) :AppKitForm {
    my ($self, $c) = @_;
    
    $self->add_final_crumb($c, "New element");
    
    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $element = $c->model('CMS::Element')->create({
            name   => $form->param_value('name'),
            site   => $c->stash->{site}->id,
            global => $form->param_value('global')||0,
        });
        
        $element->set_content($form->param_value('content'));
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

sub edit_element :Local :Args(1) :AppKitForm {
    my ($self, $c, $element_id) = @_;

    my $restricted_row = $c->model('CMS::Parameter')->find({ parameter => 'Restricted' });

    if ($restricted_row) {
        if ($c->user->users_parameters->find({ parameter_id => $restricted_row->id })) {
            unless ($c->model('CMS::ElementUser')->find({ element_id => $element_id, user_id => $c->user->id })) {
                $c->detach('/access_denied');
            }
        }
    }

    $self->add_final_crumb($c, "Edit element");
    
    my $form    = $c->stash->{form};
    my $element = $c->model('CMS::Element')->published->find({id => $element_id});
    $c->stash(element => $element);
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

        if ($form->param_value('content') ne $element->content) {
            $element->set_content($form->param_value('content'));
        }
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
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

sub delete_element :Local :Args(1) :AppKitForm {
    my ($self, $c, $element_id) = @_;

    $self->add_final_crumb($c, "Delete element");
    
    my $form    = $c->stash->{form};
    my $element = $c->model('CMS::Element')->find({id => $element_id});

    if ($form->submitted_and_valid) {
        $element->remove;
        
        $c->flash->{status_msg} = "Element deleted";
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }
    
    $c->stash->{element} = $element;
}


#-------------------------------------------------------------------------------

1;
