package App::AutoCRUD::View::Redirect;

use 5.010;
use strict;
use warnings;

use Moose;
extends 'App::AutoCRUD::View';

use namespace::clean -except => 'meta';


sub render {
  my ($self, $url, $context) = @_;

  # see http://en.wikipedia.org/wiki/303_See_Other
  return [303, [Location => $url], []]; 
}

1;


__END__



