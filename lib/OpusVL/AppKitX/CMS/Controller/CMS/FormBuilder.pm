package OpusVL::AppKitX::CMS::Controller::CMS::FormBuilder;

use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller::HTML::FormFu'; };
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
 
__PACKAGE__->config(
    appkit_name                 => 'Form Builder',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_method_group         => 'Content Management',
    appkit_method_group_order   => 1,
    appkit_shared_module        => 'CMS',
    appkit_css 					=> [ '/static/css/bootstrap.css' ],
    appkit_js					=> [ '/static/js/bootstrap.js' ],
 );

sub auto :Private {
    my ($self, $c) = @_;

    $c->stash->{section} = 'Pages';
    push @{ $c->stash->{breadcrumbs} }, {
        name    => 'Form Builder',
        url     => $c->uri_for( $c->controller->action_for('index'))
    };

    1;
}


#-------------------------------------------------------------------------------

sub base
    : Chained('/')
    : PathPart('forms')
    : CaptureArgs(0)
    : AppKitFeature('Forms - Read Access') {
    my ($self, $c) = @_;
}

sub forms
    : Chained('base')
    : PathPart('form')
    : CaptureArgs(2)
    : AppKitFeature('Forms - Read Access') {
    my ($self, $c, $site_id, $form_id) = @_;
    $c->forward('/modules/cms/sites/base', [ $site_id ]);
    my $form = $c->model('CMS::Form')->find({ site => $site_id, id => $form_id });

    unless ($form) {
        $c->flash(error_msg => "No such form");
        $c->res->redirect($c->uri_for($self->action_for('index'), [ $site_id ]));
        $c->detach;
    }
    
    $c->stash( form => $form );
}

sub index
    : Chained('/modules/cms/sites/base')
    : PathPart('forms/list')
    : Args(0)
    : AppKitFeature('Forms - Read Access') {
    my ($self, $c) = @_;
    my $site = $c->stash->{site};

    $c->stash->{forms} = [$site->forms->all];
}

sub edit_form
    : Chained('forms')
    : PathPart('edit')
    : Args(0)
    : AppKitFeature('Forms - Write Access') {
    my ($self, $c) = @_;
    my ($site, $form) = (
        $c->stash->{site},
        $c->stash->{form},
    );

    $c->stash(
        types       => [$c->model('CMS::FormsFieldType')->all],
        constraints => [$c->model('CMS::FormsConstraint')->all],
    );

    if ($c->req->body_params && $c->req->body_params->{save_form}) {
        my $constraint_rs = $c->model('CMS::FormsConstraint');
        my $params = $c->req->body_params;

        # update the page
        if (my $page_id = $params->{form_redirect}) {
            if ($page_id != $form->redirect_page->id) {
                $form->forms_submit_fields->first->update({
                    redirect => $page_id,
                });
            }
        }

        foreach my $param (keys %$params) {
            my $constraint;
            if ($param =~ /field-(.+)-(\d+?)/) {
                my ($type, $priority) = ($1, $2);

                # FIXME: For the love of god I need to fix this
                # ie: DO NOT USE THE PRIORITY BECAUSE THAT IS STUPID
                if (my $field = $form->forms_fields->search({ priority => $priority })->first) {
                    if ($field->label ne $params->{$param}) {
                        $field->update({ label => $params->{$param} });
                    }
                }

                # We may make use of this bit in the future, but for now
                # let's leave it alone
                if ($params->{"constraint-id-${priority}"} and 0) {
                    # This field has a constraint
                    my $constraint_id = $params->{"constraint-id-${priority}"};
                    if (my $const = $constraint_rs->find($constraint_id)) {
                        $constraint = $const->id;

                        # FIXME: For the love of god I need to fix this
                        # ie: DO NOT USE THE PRIORITY BECAUSE THAT IS STUPID
                        if (my $f = $form->forms_fields->search({ priority => $priority })->first) {
                            $f->forms_fields_constraints->first->update({
                                constraint_id => $constraint,
                            });
                        }
                    }
                } # / constraint update

                # update select fields
                if ($type eq 'select') {
                    if ($params->{"select-opts-${priority}"}) {
                        if (my $f = $form->forms_fields->search({ priority => $priority })->first) {
                            $f->update({ fields => $params->{"select-opts-${priority}"} });
                        }
                    }
                }
            }
        }

        $c->flash(status_msg => 'Updated ' . $form->name);
        $c->res->redirect($c->req->uri);
        $c->detach;
    }
    
}

sub new_form
    : Chained('/modules/cms/sites/base')
    : PathPart('forms/new')
    : Args(0)
    : AppKitFeature('Forms - Write Access') {
    my ($self, $c) = @_;
    my $site       = $c->stash->{site};

    $c->stash(
        types       => [$c->model('CMS::FormsFieldType')->all],
        constraints => [$c->model('CMS::FormsConstraint')->all],
    );

    if ($c->req->body_params and $c->req->body_params->{save_form}) {
        my $constraints = $c->model('CMS::FormsConstraint');
        my $params = $c->req->body_params;
        if ($params->{form_name}) {

            my $form_opts = {};

            if ($c->model('CMS::Form')->find({ name => $params->{form_name} })) {
                $c->flash(error_msg => "Form " . $params->{form_name} . " already exists");
                $c->res->redirect($c->req->uri);
                $c->detach;
            }

            my $form = $site->create_related('forms', {
                owner_id => $c->user->id,
                name     => $params->{form_name},
            });

            if ($form) {
                if (not $params->{form_redirect}) {
                    $c->flash(error_msg => "You must select a page to redirect to");
                    $c->res->redirect($c->req->uri);
                    $c->detach;
                }
                foreach my $param (keys %$params) {
                    my $constraint;
                    if ($param =~ /field-(.+)-(\d+?)/) {
                        my ($type, $priority) = ($1, $2);
                        if ($params->{"constraint-id-${priority}"}) {
                            # This field has a constraint
                            my $constraint_id = $params->{"constraint-id-${priority}"};
                            if (my $const = $constraints->find($constraint_id)) {
                                $constraint = $const->id;
                            }
                        }

                        # TODO: probably exclude submits from this...
                        $form_opts->{ $params->{$param} } = {
                            type        => $type,
                            priority    => $priority,
                            constraint  => $constraint,
                        };

                        # TODO: Get email address from label /email/ ?
                        if ($type eq 'submit') {
                            my $submit = $form->create_related('forms_submit_fields', {
                                value       => ucfirst $params->{$param},
                                email       => 'brad.haywood@opusvl.com', #FIXME: use this as the recipient email?
                                submitted   => DateTime->now(),
                                redirect    => $params->{form_redirect},
                            });
                        } 
                    }
                }

                my $name;
                my $types = $c->model('CMS::FormsFieldType');
                foreach my $opt (keys %$form_opts) {
                    $name = lc $opt;
                    $name =~ s/\s/_/g;
                    $name =~ s/[^\w\d\s]//g;
                    my $type = $types->find({ type => ucfirst($form_opts->{$opt}->{type}) });
                    if ($type) {
                        my $new_field = $form->create_related('forms_fields', {
                            name     => $name,
                            label    => ucfirst $opt,
                            priority => $form_opts->{$opt}->{priority},
                            type     => $type->id,
                        });

                        if ($type->type eq 'Select') {
                            my $opts  = $params->{"select-opts-" . $new_field->priority};
                            $new_field->update({ fields => $opts });
                        }

                        if ($form_opts->{$opt}->{constraint}) {
                            if ($new_field) {
                                $new_field->create_related('forms_fields_constraints', {
                                    constraint_id => $form_opts->{$opt}->{constraint},
                                });
                            }
                        }
                    }
                    else {
                        $c->flash(error_msg => "Could not find type: $form_opts->{$opt}->{type}");
                        $c->res->redirect($c->req->uri);
                        $c->detach;
                    }
                }

                $c->flash(status_msg => "Successfully created new form");
                $c->res->redirect($c->uri_for($self->action_for('index'), [ $site->id ]));
                $c->detach;
            }
        }
        else {
            $c->flash(error_msg => "Form name is required");
            $c->res->redirect($c->req->uri);
            $c->detach;
        }
    }
}

sub submitted_forms
    : PortletName('Submitted Forms')
    : AppKitFeature('Portlets') {

    my ($self, $c) = @_;

    my $forms = $c->model('CMS::Form')->search({
        owner_id => $c->user->id,
    }, { rows => 5, order_by => { -desc => 'id' }});

    my @fields;
    my $min = DateTime->now->subtract(days => 5);

    if ($forms->count > 0) {
        for my $form ($forms->all) {
            if (my $submit = $form->forms_submit_fields->
                search(undef, { order_by => { -asc => 'submitted' } })->first) {

                if (my $submitted = $submit->submitted) {
                    if ($submitted > $min) {
                        push @fields, {
                            form      => $form->name,
                            submitted => $submitted,
                        };
                    }
                }
            }
        }

        $c->stash(fields => \@fields);
    }
}

sub delete_form
    : Chained('forms')
    : Args(0)
    : AppKitFeature('Forms - Write Access') {

    my ($self, $c) = @_;
    my $site       = $c->stash->{site};
    my $form       = $c->stash->{form};

    if ($c->req->body_params) {
        if ($c->req->body_params->{submit_yes}) {
            $form->forms_submit_fields->delete;
            $form->forms_content->delete;
            $form->forms_fields->delete;
            $form->delete;
            $c->flash(status_msg => 'Removed form ' . $form->name);
            $c->res->redirect($c->uri_for($self->action_for('index'), [ $site->id ]));
            $c->detach;
        }
        elsif ($c->req->body_params->{submit_no}) {
            $c->res->redirect($c->uri_for($self->action_for('index'), [ $site->id ]));
            $c->detach;
        }
    }
    
}

1;