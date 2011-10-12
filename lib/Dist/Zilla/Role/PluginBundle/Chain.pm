use strict;
use warnings;
package Dist::Zilla::Role::PluginBundle::Chain;
# FILENAME: Chain.pm
# CREATED: 14/09/11 18:13:36 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: A single chain element role

use Moose::Role;

requires 'post_config';

requires 'pre_config';

has name => (
  isa => 'Str', 
  is  => 'rw',
  required => 1,
);

has delete_keys => (
  isa => 'Bool',
  is  => 'rw', 
  default => 1,
);

sub own_args {
  my ( $self, $state ) = @_ ;
  my $own = {};
  my $name = $self->name;
  my $delete_keys = $self->delete_keys;
  my $re = qr/^\-chain\[n=\Q$name\E\]\.(.*$)/;
  for my $key ( keys %{  $state->{arg}->{payload} } ){
    next unless $key =~ $re;
    $own{$1} = $state->{arg}->{payload}->{$key};
    if ( $delete_keys ) {
      delete $state->{arg}->{payload}->{$key};
    }
  }
  return $own;
}

no Moose::Role;
1;


