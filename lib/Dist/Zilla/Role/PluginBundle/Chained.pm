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

sub _chained_name_from_class {
  my ( $self, $chainmeta ) = @_;
  return if exists $chainmeta->{name};
  $chainmeta->{name} = $chainmeta->{instance}->name if $chainmeta->{instance}->can('name');
  return if exists $chainmeta->{name};
  my $name = $chainmeta->{classname};
  $name =~ s/^Dist::Zilla::Plugin::Chain:://;
  $name = lc($name);
  $name =~ s/[^a-z0-9:]+/_/g;
  $chainmeta->{name} = $name;
  return;
}

sub _chained_vivify_scalar {
  # Dist::Zilla::Plugin::Chain::Foo  => [ 'foo' , 'Dist::Zilla::Plugin::Chain::Foo' , [] ];
  my ( $self, $classname ) = @_;
  my $chainmeta = {};
  $chainmeta->{passed_as} = 'scalar';
  $chainmeta->{classname} = $self->_chained_load_class($chain);
  $chainmeta->{instance}  = $chainmeta->{classname}->new();
  $self->_chained_name_from_class($chainmeta);
  return $chainmeta;
}

sub _chained_vivify_hashref {
  my ( $self, $hashref ) = @_;
  my $conf = { payload => [], };
  $conf->{classname} = delete $hashref->{classname} if exists $hashref->{classname};
  $conf->{name}      = delete $hashref->{name}      if exists $hashref->{name};
  $conf->{payload}   = delete $hashref->{payload}   if exists $hashref->{payload};

  for my $key ( keys %{$chain} ) {
    warn "Key $key is not recognised as a parameter for HASH based chain entries.\n";
  }
  my $chainmeta = {};
  $chainmeta->{passed_as} = 'hashref';
  $chainmeta->{classname} = $self->_chained_load_class( $conf->{classname} );
  $chainmeta->{payload}   = $conf->{payload};
  $chainmeta->{instance}  = $chainmeta->{classname}->new( @{ $conf->{payload} } );
  $chainmeta->{name}      = $conf->{name} if exists $conf->{name};
  $self->_chained_name_from_class($chainmeta);
  return $chainmeta;
}

sub _chained_vivify_name_array {
  my ( $self, $array ) = @_;
  my ( $name, $chain ) = @{$array};
  my $chainmeta = $self->_chained_load_chain($chain);
  $chainmeta->{passed_as} = 'arrayref[ name, ' . $chainmeta->{passed_as} . ']';
  $chainmeta->{name}      = $name;
  return $chainmeta;
}

sub _chained_vivify_triplet_array {
  my ( $self, $array ) = @_;
  my ( $name, $class, $payload ) = @{$array};
  my $chainmeta = $self->_chained_load_chain(
    {
      name      => $name,
      classname => $class,
      payload   => $payload,
    }
  );
  $chainmeta->{passed_as} = 'arrayref[ name, classname, payload ]';
  return $chainmeta;

}

sub _chained_metafy_blessed {
  my ( $self, $blessed ) = @_;
  my $chainmeta = {};
  $chainmeta->{passed_as} = 'bless';
  $chainmeta->{classname} = Scalar::Util::blessed($blessed);
  $chainmeta->{instance}  = $blessed;
  $self->_chained_name_from_class($chainmeta);
  return $chainmeta;
}

sub _chained_load_chain {
  my ( $self, $chain ) = @_;

  return $self->_chained_vivify_scalar($chain) if not ref $chain;
  return $self->_chained_vivify_hashref($chain) if ref $chain eq 'HASH';
  require Scalar::Util;
  return $self->_chained_metafy_blessed($chain)       if Scalar::Util::blessed($chain);
  return $self->_chained_vivify_name_array($chain)    if ( ref $chain eq 'ARRAY' and scalar @{$chain} == 2 );
  return $self->_chained_vivify_triplet_array($chain) if ( ref $chain eq 'ARRAY' and scalar @{$chain} == 3 );

  require Data::Dumper;
  local $Data::Dumper::Indent   = 1;
  local $Data::Dumper::Pad      = "   ";
  local $Data::Dumper::Useqq    = 1;
  local $Data::Dumper::Terse    = 1;
  local $Data::Dumper::Sortkeys = 1;
  die "Sorry, a chain element doesn't match any known parseable configuration type\n \$chain = " . Dumper($chain);

  return;

}

sub _chained_pre_config {
  my ( $self, $arg ) = @_;
  my $state = {};

  $state->{arg}     = $arg;
  $state->{objects} = [ map { $self->_chained_load_chain($_) } $self->chains ];
  $state->{result}  = undef;

  for my $object ( @{ $state->{objects} } ) {
    $object->pre_config($state);
  }
  return $state;
}

sub _chained_post_config {
  my ( $self, $state );

  for my $object ( reverse @{ $state->{objects} } ) {
    $object->post_config($state);
  }
  return @{ $state->{result} };
}

sub bundle_config {
  my ( $self, $arg ) = @_;

  my ($state) = $self->_chained_pre_config($arg);

  $state->{results} = [ $self->pluginbundle_config( $state->{arg} ) ];

  return $self->_chained_post_config($state);

}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
