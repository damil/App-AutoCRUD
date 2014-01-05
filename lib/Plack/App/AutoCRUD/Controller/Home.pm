package Plack::App::AutoCRUD::Controller::Home;

use 5.010;
use strict;
use warnings;

use Moose;
extends 'Plack::App::AutoCRUD::Controller';
use namespace::clean -except => 'meta';

sub serve {
  my ($self) = @_;

  $self->context->set_template("home.tt");

  return $self->app->datasources;
}

1;

__END__


