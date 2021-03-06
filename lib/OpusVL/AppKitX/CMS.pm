package OpusVL::AppKitX::CMS;
use Moose::Role;
use CatalystX::InjectComponent;
use File::ShareDir qw/module_dir/;
use namespace::autoclean;

# ABSTRACT: CMS plugin for AppKit apps

with 'OpusVL::AppKit::RolesFor::Plugin';

our $VERSION = '0.105';

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
        component => 'OpusVL::AppKitX::CMS::View::CMS::Ajax',
        as        => 'View::CMS::Ajax'
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

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::PageAttributes',
        as        => 'Controller::Modules::CMS::PageAttributes'
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::Ajax',
        as        => 'Controller::Modules::CMS::Ajax',
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::Aliases',
        as        => 'Controller::Modules::CMS::Aliases',
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::Sites',
        as        => 'Controller::Modules::CMS::Sites',
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::Domains',
        as        => 'Controller::Modules::CMS::Domains',
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::UserAccess',
        as        => 'Controller::Modules::CMS::UserAccess',
    );

    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::Plugins',
        as        => 'Controller::Modules::CMS::Plugins',
    );
    
    CatalystX::InjectComponent->inject(
        into      => $class,
        component => 'OpusVL::AppKitX::CMS::Controller::CMS::FormBuilder',
        as        => 'Controller::Modules::CMS::FormBuilder',
    );
};

1;


=head1 DESCRIPTION

=head1 METHODS

=head1 BUGS

=head1 AUTHOR

=head1 COPYRIGHT and LICENSE

Copyright (C) 2012 OpusVL

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

If you require assistance, support, or further development of this software, please contact OpusVL using the details below:

=over 4

=item *

Telephone: +44 (0)1788 298 410

=item *

Email: community@opusvl.com

=item *

Web: L<http://opusvl.com>

=back

=cut

