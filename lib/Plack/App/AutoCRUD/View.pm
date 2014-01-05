package Plack::App::AutoCRUD::View;

use 5.010;
use strict;
use warnings;

use Moose;
use namespace::clean -except => 'meta';

sub render {
  my ($self, $node, %args) = @_;

  return [500, ['Content-type' => 'text/plain'], 
               ["attempt to render() from abstract class View.pm"]];
}

1;

__END__


# parent class for views
