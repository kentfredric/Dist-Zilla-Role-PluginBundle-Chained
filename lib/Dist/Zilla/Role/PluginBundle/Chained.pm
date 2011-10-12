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
    return (
      [ 'filter' , 'Dist::Zilla::Plugin::Chain::Filter' , [ @args ] ],
      [ 'subargs', 'Dist::Zilla::Plugin::Chain::SubArgs', [ @otherargs ] ],
    );
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

sub chains {
  return ();
}

sub _chained_load_class {
  my ( $self, $class ) = @_;

  # TODO put a shorthand expansion here.
  require Class::Load;
  Class::Load::load_class($class);
  return $class;
}

sub _chained_load_chain {
  my ( $self, $chain ) = @_;

  if ( ref $chain ne 'ARRAY' ) {
    die "Chain element was not an Array ref\n";
  }
  if ( scalar @{$chain} != 3 ) {
    die "Chain element expects exactly 3 tokens, name, class and payload";
  }

  my ( $name, $class, $payload ) = @{$chain};

  my $real_class = $self->_chained_load_class($class);

  return {
    name      => $name,
    classname => $real_class,
    payload   => $payload,
    instance  => $real_class->new(
      name => $name,
      @{$payload},
    ),
  };
}

sub _chained_pre_config {
  my ( $self, $arg ) = @_;
  my $state = {
    arg     => $arg,
    objects => [ map { $self->_chained_load_chain($_) } $self->chains ],
    result  => undef,
  };

  for my $object ( @{ $state->{objects} } ) {
    $object->{instance}->pre_config($state);
  }
  return $state;
}

sub _chained_post_config {
  my ( $self, $state );

  for my $object ( reverse @{ $state->{objects} } ) {
    $object->{instance}->post_config($state);
  }
  return @{ $state->{result} };
}

sub bundle_config {
  my ( $self, $arg ) = @_;

  my ($state) = $self->_chained_pre_config($arg);

  $state->{results} = [ $self->pluginbundle_config( $state->{arg} ) ];

  return $self->_chained_post_config($state);

}

no Moose::Role;

1;
