package Plack::App::AutoCRUD::Controller::Schema;

use 5.010;
use strict;
use warnings;

use Moose;
extends 'Plack::App::AutoCRUD::Controller';
use YAML;
use Clone qw/clone/;

use namespace::clean -except => 'meta';


sub serve {
  my ($self) = @_;

  my $context = $self->context;
  $context->set_template("schema.tt");
  return $context->datasource->tablegroups;
}

1;


__END__



