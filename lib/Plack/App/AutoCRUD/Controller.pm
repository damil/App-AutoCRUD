package Plack::App::AutoCRUD::Controller;

use 5.010;
use strict;
use warnings;

use Moose;
use Time::HiRes qw/time/;
use namespace::clean -except => 'meta';


has 'context' => (is => 'ro', isa => 'Plack::App::AutoCRUD::Context',
                  required => 1,
                  handles => [qw/app config dir logger datasource/]);


sub respond {
  my ($self) = @_;

  my $t0   = time;
  my $data = $self->serve();
  my $t1   = time;

  my $context = $self->context;
  $context->set_process_time($t1-$t0);

  my $view = $context->view;
  $view->render($data, $context);
}

sub redirect {
  my ($self, $url) = @_;

  my $context    = $self->context;
  my $view_class = $context->app->find_class("View::Redirect")
    or die "no Redirect view";
  $context->set_view($view_class->new);
  return $url;
}




1;

__END__


# parent class for controllers
