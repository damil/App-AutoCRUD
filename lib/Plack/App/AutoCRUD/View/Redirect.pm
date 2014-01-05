package Plack::App::AutoCRUD::View::Redirect;

use 5.010;
use strict;
use warnings;

use Moose;
extends 'Plack::App::AutoCRUD::View';

use namespace::clean -except => 'meta';


sub render {
  my ($self, $url, $context) = @_;

  return [302, [Location => $url], []];
}

1;


__END__



