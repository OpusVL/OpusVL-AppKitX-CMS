package OpusVL::AppKitX::CMS;
use Moose::Role;
use CatalystX::InjectComponent;
use File::ShareDir qw/module_dir/;
use namespace::autoclean;

with 'OpusVL::AppKit::RolesFor::Plugin';

our $VERSION = '0.01';

after 'setup_components' => sub {
    my $class = shift;
   
    $class->add_paths(__PACKAGE__);
    
    # .. inject your components here ..
    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Model::CMS',
        as        => 'Model::CMS'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::View::CMS',
        as        => 'View::CMS::Page'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::View::CMS',
        as        => 'View::CMS::Element'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS',
        as        => 'Controller::Modules::CMS'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::Pages',
        as        => 'Controller::Modules::CMS::Pages'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::Templates',
        as        => 'Controller::Modules::CMS::Templates'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::Assets',
        as        => 'Controller::Modules::CMS::Assets'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::Elements',
        as        => 'Controller::Modules::CMS::Elements'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::Tags',
        as        => 'Controller::Modules::CMS::Tags'
    );
};

1;

=head1 NAME

OpusVL::AppKitX::CMS - 

=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

=head1 AUTHOR

=head1 COPYRIGHT and LICENSE

Copyright (C) 2012 OpusVL

This software is licensed according to the "IP Assignment Schedule" provided with the development project.

=cut

