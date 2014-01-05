package Plack::App::AutoCRUD::Context;

use 5.010;
use strict;
use warnings;

use Moose;
use MooseX::SemiAffordanceAccessor; # writer methods as "set_*"
use Carp;
use Scalar::Util qw/reftype/;
use Encode       ();

use namespace::clean -except => 'meta';


has 'app'          => (is => 'ro', isa => 'Plack::App::AutoCRUD', required => 1,
                       handles => [qw/config dir/]);
has 'req'          => (is => 'ro', isa => 'Plack::Request', required => 1,
                       handles => [qw/logger/]);
has 'req_data'     => (is => 'ro', isa => 'HashRef',
                       builder => '_req_data', lazy => 1, init_arg => undef);
has 'base'         => (is => 'ro', isa => 'Str',
                       builder => '_base', lazy => 1, init_arg => undef);
has 'path'         => (is => 'rw', isa => 'Str',
                       builder => '_path', lazy => 1);
has 'template'     => (is => 'rw', isa => 'Str');
has 'view'         => (is => 'rw', isa => 'Plack::App::AutoCRUD::View',
                       builder => '_view', lazy => 1);
has 'process_time' => (is => 'rw', isa => 'Num');

has 'datasource'   => (is => 'rw', isa => 'Plack::App::AutoCRUD::DataSource',
                       handles => [qw/dbh schema/]);


sub _view {
  my $self = shift;

  return $self->app->find_class("View::TT")->new;
}


sub _req_data {
  my $self = shift;

  require CGI::Expand;
  my $req_data = CGI::Expand->expand_cgi($self->req);
  _decode_utf8($req_data);
  return $req_data;
}

sub _base {
  my $self = shift;

  my $base = $self->req->base->as_string;
  $base .= "/" unless $base =~ m[/$]; # force trailing slash
  return $base
}

sub _path {
  my $self = shift;

  return $self->req->path;
}


sub extract_path_segments {
  my ($self, $n_segments) = @_;

  # check argument
  $n_segments >= 0             or croak "illegal n_segments: $n_segments";
  $n_segments < 2 or wantarray or croak "n_segments too big for scalar context";

  # extract segments
  my $path = $self->path;
  my @segments;
  while ($n_segments-- && $path =~ s[^/([^/]*)][]) {
    push @segments, $1;
  }

  # inject remaining path (without segments) back into context
  $self->set_path($path);

  # contextual return
  return wantarray ? @segments : $segments[0];
}



sub maybe_set_view_from_path {
  my $self = shift;

  my $path = $self->path;
  if ($path =~ s/\.(\w+)$//) { # e.g. /TABLE/foo/list.yaml?...
    my $requested_view = $1;
    my $view_class = $self->app->find_class("View::".ucfirst $requested_view);
    if ($view_class) {
      $self->set_view($view_class->new);
      $self->set_path($path);
    };
  }
}

#======================================================================
# UTILITY FUNCTIONS
#======================================================================


sub _decode_utf8 {
  for (reftype $_[0]) {
    when ('ARRAY') {
      _decode_utf8($_) foreach @{$_[0]};
    }
    when ('HASH') {
      _decode_utf8($_) foreach values %{$_[0]};
    }
    default {
      $_[0] = Encode::decode_utf8($_[0], Encode::FB_CROAK);
    }
  }
}


1;

__END__

=head1 NAME

Plack::App::AutoCRUD::Context - Context information for handling a single request

=head1 DESCRIPTION

An instance of this class holds a bag of information for serving a
single request. It is passed around for sharing information between
controllers and view; its lifetime ends when the response is sent.
