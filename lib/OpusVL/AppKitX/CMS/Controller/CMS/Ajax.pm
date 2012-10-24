package OpusVL::AppKitX::CMS::Controller::CMS::Ajax;

use 5.010;
use Moose;
use namespace::autoclean;
BEGIN { extends 'Catalyst::Controller' }
with 'OpusVL::AppKit::RolesFor::Controller::GUI';
with 'OpusVL::AppKitX::CMS::Controller::CMS::Base';

__PACKAGE__->config
(
    appkit_name                 => 'CMS',
    appkit_icon                 => '/static/modules/cms/cms-icon-small.png',
    appkit_myclass              => 'OpusVL::AppKitX::CMS',
    appkit_js                     => ['/static/js/nicEdit.js', '/static/js/cms.js'],
    # appkit_method_group         => 'Extension A',
    # appkit_method_group_order   => 2,
    appkit_shared_module        => 'CMS',
    #appkit_css                  => ['/static/modules/cms/cms.css'],
);


#-------------------------------------------------------------------------------

sub auto :Private {
    my ($self, $c) = @_;
    $c->stash->{no_wrapper} = 1;
    #$c->stash->{current_view} = 'CMS::Ajax';
}

sub index :Path :Args(0) {
    my ($self, $c) = @_;
}

sub list_elements :Local :Args(0) {
    my ($self, $c) = @_;
    #$c->stash->{template} = 'list_elements.tt';
    $c->stash->{elements} = $c->model('CMS::Element')->available;
}

sub load_controls :Local :Args(0) {
    my ($self, $c) = @_;
    my $site              = $c->model('CMS::Site')->find($c->stash->{site}->id);
    $c->stash->{assets}   = [ $site->assets->available->all ];
    $c->stash->{elements} = $site->elements->available;
    $c->stash->{pages}    = $c->model('CMS::Page')->published;
    
    if (my $page_id = $c->req->param('page_id')) {
        $c->stash->{page} = $c->model('CMS::Page')->published->find({id => $page_id});
    }
}

sub preview_panel :Local :Args(1) {
    my ($self, $c, $page_id) = @_;
    my $page = $c->model('CMS::Page')->find($page_id);

    $c->stash->{page} = $page;
}

sub preview_page :Local :Args(0) {
    my ($self, $c) = @_;

    if ($c->req->body_params->{page_id} and $c->req->body_params->{content}) {
        my $page_id = $c->req->body_params->{page_id};
        my $content = $c->req->body_params->{content};
        my $page = $c->model('CMS::Page')->find($page_id);
        my $site = $c->model('CMS::SitesUser')->find({ site_id => $page->site->id, user_id => $c->user->id });

        if ($site) {
            my $page = $c->model('CMS::Page')->find($page_id);
            if ($page) {
                my $asset_rs = $site->site->assets;
                $c->stash->{me}  = $page;
                $c->stash->{cms} = {
                    asset => sub {
                        if (my $asset = $asset_rs->published->find({id => shift})) {
                            return $c->uri_for($self->action_for('_asset'), $asset->id, $asset->filename);
                        }
                    },
                    attachment => sub {
                        if (my $attachment = $c->model('CMS::Attachment')->find({id => shift})) {
                            return $c->uri_for($self->action_for('_attachment'), $attachment->id, $attachment->filename);
                        }
                    },
                    element => sub {
                        if (my $element = $c->model('CMS::Element')->published->find({id => shift})) {
                            return $element->content;
                        }
                    },
                    page => sub {
                        return $c->model('CMS::Page')->published->find({id => shift});
                    },
                    pages => sub {
                        return $c->model('CMS::Page')->published->attribute_search(@_);
                    },
                    param => sub {
                        return $c->req->param(shift);
                    },
                    toplevel => sub {
                        return $c->model('CMS::Page')->published->toplevel;
                    },
                    thumbnail => sub {
                        return $c->uri_for($self->action_for('_thumbnail'), @_);
                    },
                };
                
                if (my $template = $page->template->content) {
                    $template = '[% BLOCK content %]' . $content . '[% END %]' . $template;
                    $c->stash->{template}   = \$template;
                    $c->stash->{no_wrapper} = 1;
                }
                
                $c->forward($c->view('CMS'));
            }
        }
        else {
            $c->flash->{error_msg} = "Sorry, but you don't have access to this page";
            $c->res->redirect($c->req->referer);
            $c->detach;
        }
    }
}

sub _asset :Local :Args(2) {
    my ($self, $c, $asset_id, $filename) = @_;
    
    if (my $asset = $c->model('CMS::Asset')->published->find({id => $asset_id})) {
        $c->response->content_type($asset->mime_type);
        $c->response->body($asset->content);
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

sub _attachment :Local :Args(2) {
    my ($self, $c, $attachment_id, $filename) = @_;
    
    if (my $attachment = $c->model('CMS::Attachment')->find({id => $attachment_id})) {
        $c->response->content_type($attachment->mime_type);
        $c->response->body($attachment->content);
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

sub _thumbnail :Local :Args(2) {
    my ($self, $c, $type, $id) = @_;
    
    given ($type) {
        when ('asset') {
            if (my $asset = $c->model('CMS::Asset')->published->find({id => $id})) {
                $c->stash->{image} = $asset->content;
            }
        }
        when ('attachment') {
            if (my $attachment = $c->model('CMS::Attachment')->find({id => $id})) {
                $c->stash->{image} = $attachment->content;
            }
        }
    }
    
    if ($c->stash->{image}) {
        $c->stash->{x}       = $c->req->param('x') || undef;
        $c->stash->{y}       = $c->req->param('y') || undef;
        $c->stash->{zoom}    = $c->req->param('zoom') || 100;
        $c->stash->{scaling} = $c->req->param('scaling') || 'fill';
        
        unless ($c->stash->{x} || $c->stash->{y}) {
            $c->stash->{y} = 50;
        }
        
        $c->forward($c->view('CMS::Thumbnail'));
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

return qr|Sure, this could just be 1, but that's boring!|; 
