use strict;
use warnings;

package Dist::Zilla::Role::PluginBundle::Chained;

# ABSTRACT: A Base Layer for adding Chainable configuration modules to a Bundle.

use Moose::Role;
with 'Dist::Zilla::Role::PluginBundle';


=head1 DESCRIPTION

The point of this module is to provide an infrastructure for aggregating
various composable behaviours into a given PluginBundles' functionality.

By default, A PluginBundle only really exists of the one method C<bundle_config>, and all input state 
is passed to it directly, and the bundle config merely returns a codified configuration.

This somewhat makes it a bit hard to be composeable, for instance,
adding features to filter out any given plugin, or pass arbitrary flags to plugins included,
etc.

This is a StopGap solution for that problem.

=cut

=head1 USE

This role is obviously not much use to use directly, unless you are
developing a plugin bundle.

Default use of this should be identical to L<Dist::Zilla::Role::PluginBundle> except for the name
of the sub.


  package Foo;
  use Moose;
  with 'Dist::Zilla::Role::PluginBundle::Chained';

  sub pluginbundle_config {
    my ( $self, $arg ) = @_ ;
    # $arg = { 
    #   name    => ...,
    #   package => ...,
    #   payload => ...,
    # };
      ... the usual stuff ...
    return (
      [ $name , $class, $payload ]    
    );
  }

And it should just behave as usual.

However, you can then augment it with the following:

  sub chains {
    return map {
      'Dist::Zilla::Plugin::Chain::' . $_ 
    } qw( Mangler OtherMangler );
  }

And now the parameters passed to the bundle are able to be pre-filtered/read
prior to C<pluginbundle_config> being called.

And values you return are able to be augmented during return.

In this example, how this works should be similar to this code in a standard bundle.

  sub bundle_config {
    my ( $self, $arg ) = @_;
    my $manglerchain = Dist::Zilla::Plugin::Chain::Mangler->new();
    my $othermanglerchain = Dist::Zilla::Plugin::Chain::OtherMangler->new();
    $manglerchain->input( $arg );
    $othermanglerchain->input( $arg );

    ... normal code ...

    return $manglerchain->output( 
      $othermanglerchain->output(
        [  $name , $class, $payload  ]
      )
    );
  }

=cut

requires 'pluginbundle_config';

sub bundle_config {

}



__PACKAGE__->meta->make_immutable;
no Moose;

1;
