package OpusVL::AppKitX::CMS::Controller::CMS::Tags;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    appkit_name                 => 'CMS',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    # appkit_method_group         => 'Extension A',
    # appkit_method_group_order   => 2,
    appkit_shared_module        => 'CMS',
    #appkit_css                  => ['/static/modules/cms/cms.css'],
);

 
#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
        $c->detach;
    }
    
    $c->stash->{section} = 'Tags';
    
    $self->add_breadcrumb($c, {
        name    => 'Tags',
        url     => $c->uri_for( $c->controller->action_for('index'))
    });
}


#-------------------------------------------------------------------------------

sub index :Path :Args(0) :NavigationName('Tags') {
    my ($self, $c) = @_;
    
    $c->stash->{tags} = [$c->model('CMS::TagGroups')->all];
}


#-------------------------------------------------------------------------------

sub new_tag :Local :Args(0) :AppKitForm {
    my ($self, $c) = @_;

    $self->add_final_crumb($c, "New tag");
    
    my $form = $c->stash->{form};
    if ($form->submitted_and_valid) {
        my $tag = $c->model('CMS::TagGroups')->create({
            name     => $form->param_value('name'),
            cascade  => $form->param_value('cascade') || 0,
            multiple => $form->param_value('multiple') || 0,
        });
        
        $c->res->redirect($c->uri_for($c->controller->action_for('index')));
    }
}


#-------------------------------------------------------------------------------

sub manage_values :Local :Args(1) :AppKitForm {
    my ($self, $c, $tag_group_id) = @_;
    
    $self->add_final_crumb($c, "Manage tag values");
    
    my $tag_group = $c->model('CMS::TagGroups')->find({id => $tag_group_id});
    my $form      = $c->stash->{form};
    my $fieldset  = $form->get_all_element({name => 'current_values'});
    
    if (my @values = $tag_group->tags->all) {
        foreach my $value (@values) {
            $fieldset->element({
                type     => 'Multi',
                label    => 'Name',
                elements => [
                    {
                        type  => 'Text',
                        name  => 'value_name_' . $value->id,
                        value => $value->name,
                        constraints => [
                            { type => 'Required' },
                        ],
                    },
                    {
                        type  => 'Checkbox',
                        name  => 'delete_value_' . $value->id,
                        label => 'Delete',
                    }
                ]
            });
        }
    } else {
        $fieldset->element({
            type    => 'Block',
            tag     => 'p',
            content => 'No tag values have been defined',
        });
    }
    
    $form->process;
    
    if ($form->submitted_and_valid) {
        VALUE: foreach my $value ($tag_group->tags->all) {
            if ($form->param_value('delete_value_' . $value->id)) {
                $value->delete;
                next VALUE;
            }
            if (($form->param_value('value_name_' . $value->id) ne $value->name)) {
                $value->update({
                    name => $form->param_value('value_name_' . $value->id),
                });
            }
        }
        
        if ($form->param_value('new_value_name')) {
            if (my $new_value = $tag_group->create_related('tags', {
                name => $form->param_value('new_value_name')
            })) {
                $c->flash->{status_msg} = "New tag value added";
            } else {
                $c->flash->{error_msg} = "Error creating value!";
            }
        }
        
        $c->res->redirect($c->req->uri);
        $c->detach;
    }
}


#-------------------------------------------------------------------------------

1;