package OpusVL::AppKitX::CMS::Controller::CMS::Root;

use Moose;
use namespace::autoclean;
BEGIN { extends 'OpusVL::AppKit::Controller::Root'; };
 
__PACKAGE__->config( namespace => '');

sub default :Private {
    my ($self, $c) = @_;
    
    $c->log->debug("********** Running CMS lookup against:" . $c->req->path );
    
    if (my $page = $c->model('CMS::Pages')->published->find({url => '/'.$c->req->path})) {
        $c->stash->{me} = $page;
        $c->stash->{asset} = sub {
            if (my $asset = $c->model('CMS::Assets')->published->find({id => shift})) {
                return $c->uri_for($c->controller->action_for('_asset'), $asset->id, $asset->filename);
            }
        };
        $c->stash->{attachment} = sub {
            if (my $attachment = $c->model('CMS::Attachments')->find({id => shift})) {
                return $c->uri_for($c->controller->action_for('_attachment'), $attachment->id, $attachment->filename);
            }
        };
        $c->stash->{element} = sub {
            if (my $element = $c->model('CMS::Elements')->published->find({id => shift})) {
                my $content = $element->content;
                return $c->view('CMS::Element')->render($c, \$content);
            }
        };
        $c->stash->{page} = sub {
            if (my $page = $c->model('CMS::Pages')->find({id => shift})) {
                return $page;
            }
        };
        
        if (my $template = $page->template->content) {
            $template = '[% BLOCK content %]' . $page->content . '[% END %]' . $template;
            $c->stash->{template}   = \$template;
            $c->stash->{no_wrapper} = 1;
        }
        
        #$c->log->debug("Template:");
        #$c->log->debug(${$c->stash->{template}});
        
        #$c->response->body($c->view('CMS')->render($c, $c->stash->{template}));
        $c->forward($c->view('CMS::Page'));
    } else {
        if (my $page = $c->model('CMS::Pages')->published->find({url => '/404'})) {
            $c->stash->{page} = $page;
            
            if (my $template = $page->template->content) {
                $c->stash->{template} = \$template;
                $c->stash->{no_wrapper} = 1;
            }
        } else {
            OpusVL::AppKit::Controller::Root::default($self,$c);
        }
    }
}

sub _asset :Local :Args(2) {
    my ($self, $c, $asset_id, $filename) = @_;
    
    if (my $asset = $c->model('CMS::Assets')->published->find({id => $asset_id})) {
        $c->response->content_type($asset->mime_type);
        $c->response->body($asset->content);
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

sub _attachment :Local :Args(2) {
    my ($self, $c, $attachment_id, $filename) = @_;
    
    if (my $attachment = $c->model('CMS::Attachments')->find({id => $attachment_id})) {
        $c->response->content_type($attachment->mime_type);
        $c->response->body($attachment->content);
    } else {
        $c->response->status(404);
        $c->response->body("Not found");
    }
}

sub index 
    :Path('/_admin') 
    :Args(0) 
    :AppKitFeature('Home Page')
{
    OpusVL::AppKit::Controller::Root::index(@_);
    #my ( $self, $c ) = @_;
    #
    #$c->_appkit_stash_portlets;
    #
    #$c->stash->{template} = 'index.tt';
    #$c->stash->{homepage} = 1;
}