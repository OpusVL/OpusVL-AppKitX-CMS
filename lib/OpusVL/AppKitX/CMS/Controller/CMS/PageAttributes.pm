package OpusVL::AppKitX::CMS::Controller::CMS::PageAttributes;

use 5.14.0;
use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config
(
    appkit_name                 => 'Page Attributes',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_shared_module        => 'CMS',
    appkit_method_group         => 'Content Management',
    appkit_method_group_order   => 1,
    appkit_css                  => ['/static/css/bootstrap.css'],
);

 
#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;
    
    $c->stash->{section} = 'Page Attributes';
    
    $self->add_breadcrumb($c, {
        name    => 'Page Attributes',
        url     => $c->uri_for( $c->controller->action_for('index'))
    });
}


#-------------------------------------------------------------------------------

sub index 
    : Chained('/modules/cms/sites/base')
    : PathPart('pages/attributes')
    : Args(0)
    : AppKitForm
    : AppKitFeature('Attributes - Read Access')
{
    my($self, $c) = @_;
    my $site      = $c->stash->{site};

    if ($c->req->param('cancel')) {
        $c->res->redirect($c->req->uri);
        $c->detach;
    }

    my $form    = $c->stash->{form};
    
    foreach my $object_type (qw/page attachment/) {
        my $type_rs  = $c->model('CMS::' . ucfirst($object_type) . 'AttributeDetail');
        my @types    = $type_rs->active->all;
        my $fieldset = $form->get_all_element('current_' . $object_type . '_attributes');
        my $repeater = $form->get_all_element($object_type . '_rep');
        my $count    = $form->param_value($object_type . '_element_count');
        unless($count)
        {
            $count = scalar @types;
            $repeater->repeat($count);
            $form->process;
        }
        unless(@types)
        {
            $fieldset->element({
                type    => 'Block',
                tag     => 'p',
                content => 'No attributes have been defined.',
            });
        }
    }

    if($form->submitted_and_valid)
    {
        foreach my $object_type (qw/page attachment/) {
            my $type_rs = $c->model('CMS::' . ucfirst($object_type) . 'AttributeDetail');
            my $count   = $type_rs->active->count;
            my $name    = $form->param_value($object_type.'_name');
            my $code    = $form->param_value($object_type.'_code');
            my $type    = $form->param_value($object_type.'_type');
            
            if($name && $code)
            {
                my $source = { 
                    name    => $name,
                    code    => $code,
                    type    => $type,
                };
                
                if ($object_type eq 'path') {
                    $source->{cascade} = $form->param_value($object_type.'_cascade') || 0;
                }
                
                $type_rs->create($source);
            }
            
            for(my $i = 1; $i <= $count; $i++)
            {
                my $id          = $form->param_value($object_type."_id_$i");
                my $delete_flag = $form->param_value($object_type."_delete_$i");
                my $source      = $type_rs->find({ id => $id });
                
                if ($delete_flag)
                {
                    $source->update({ active => 0 });
                }
                else
                {
                    # only name editable
                    $source->name($form->param_value($object_type."_name_$i"));
                    $source->cascade($form->param_value($object_type."_cascade_$i") || 0) if ($object_type eq 'path');
                    $source->update;
                }
            }
        }
        
        $c->flash->{status_msg} = 'Saved';
        $c->res->redirect($c->req->uri);
        $c->detach;
    }
    else
    {
        my $defaults;
        
        foreach my $object_type (qw/page attachment/) {
            my $type_rs = $c->model('CMS::' . ucfirst($object_type) . 'AttributeDetail');
            my @types   = $type_rs->active->all;
            my $count   = scalar @types;
            my $i       = 1;
            my %links   = map { $_->parent->repeatable_count => $_ } 
                              @{$form->get_all_elements($object_type . '_link')};
                              
            for my $type (@types)
            {
                $defaults->{$object_type."_id_$i"}   = $type->id;
                $defaults->{$object_type."_name_$i"} = $type->name;
                $defaults->{$object_type."_type_$i"} = $type->type;
                $form->get_all_element({name => $object_type."_name_$i"})->attributes->{title} = $type->code;
                
                if ($object_type eq 'page') {
                    $defaults->{"page_cascade_$i"} = $type->cascade;
                }
                
                if($type->type eq 'select')
                {
                    $links{$i}->attributes->{href} = $self->value_link($c, $object_type, $type);
                    my $text  = $links{$i}->content();
                    my $count = $type->field_values->count;
                    $links{$i}->content($text . " ($count)");
                }
                else
                {
                    my $l = $links{$i};
                    $l->parent->remove_element($l);
                }
                $i++;
            }
            $defaults->{$object_type. '_element_count'} = $count;
        }
        
        $form->default_values($defaults);
    }
}


#-------------------------------------------------------------------------------

sub value_link
{
    my ($self, $c, $object_type, $type) = @_;
    return $c->uri_for($self->action_for('edit_values'), [ $object_type, $type->code ]);
}


#-------------------------------------------------------------------------------

sub value_chain
    : Chained('/')
    : PathPart('admin/globalfields')
    : CaptureArgs(2)
    : AppKitFeature('Attributes - Read Access')
{
    my ($self, $c, $object_type, $code) = @_;
    $c->log->debug("**** $object_type **** $code");
    $c->detach('/not_found') unless $code;
    
    my $value = do {
        given ($object_type) {
            when ('page') {
                $c->model('CMS::PageAttributeDetail')->active->find({ code => $code });
            }
            when ('attachment') {
                $c->model('CMS::AttachmentAttributeDetail')->active->find({ code => $code });
            }
        }
    };
    
    $c->detach('/not_found') unless $value;
    $c->stash->{value} = $value;

}
    
    
#-------------------------------------------------------------------------------

sub edit_values
    : Chained('value_chain')
    : PathPart('edit')
    : AppKitForm
    : AppKitFeature('Attributes - Write Access')
{
    my ($self, $c) = @_;

    my $prev_link = $c->uri_for($self->action_for('index'));
    if ($c->req->param('cancel')) {
        $c->res->redirect($prev_link);
        $c->detach;
    }
    my $value = $c->stash->{value};

    $self->add_final_crumb($c, $value->code);
    my $type_rs = $value->field_values;
    my @types = $type_rs->all;
    my $form = $c->stash->{form};

    my $fieldset = $form->get_all_element('current_values');
    my $repeater = $form->get_all_element('rep');
    my $count = $form->param_value('element_count');
    unless($count)
    {
        $count = scalar @types;
        $repeater->repeat($count);
        $form->process;
    }
    unless(@types)
    {
        $fieldset->element({
            type    => 'Block',
            tag     => 'p',
            content => 'No values have been setup.',
        });
    }

    if ($c->req->param('cancel')) {
        #$c->res->redirect($c->uri_for($c->controller->action_for('index'), [ $site->id ]));
        $c->detach;
    }

    if($form->submitted_and_valid)
    {
        my $value = $form->param_value('value');
        if($value)
        {
            my $source = $type_rs->create({ 
                value => $value,
            });
        }
        for(my $i = 1; $i <= $count; $i++)
        {
            my $id = $form->param_value("id_$i");
            my $delete_flag = $form->param_value("delete_$i");
            my $source = $type_rs->find({ id => $id });
            if($delete_flag)
            {
                $source->delete;
            }
            else
            {
                my $value = $form->param_value("value_$i");
                $source->update({ 
                    value => $value,
                });
            }
        }

        $c->flash->{status_msg} = 'Saved';
        $c->res->redirect($c->req->uri);
        $c->detach;
    }
    else
    {
        my $defaults;
        my $i = 1;
        for my $type (@types)
        {
            $defaults->{"id_$i"} = $type->id;
            $defaults->{"value_$i"} = $type->value;
            $i++;
        }
        $form->default_values($defaults);
    }
}


#-------------------------------------------------------------------------------

1;