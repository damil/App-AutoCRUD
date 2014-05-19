package Plack::App::AutoCRUD::Controller::Table;

use 5.010;
use strict;
use warnings;

use Moose;
extends 'Plack::App::AutoCRUD::Controller';
use SQL::Abstract::More;
use List::MoreUtils            qw/mesh firstval/;
use Clone                      qw/clone/;
use JSON;
use URI;

use namespace::clean -except => 'meta';

#----------------------------------------------------------------------
# entry point to the controller
#----------------------------------------------------------------------
sub serve {
  my ($self) = @_;

  my $context = $self->context;

  # extract from path : table name and method to dispatch to
  my ($table, $meth_name) = $context->extract_path_segments(2)
    or die "URL too short, missing table and method name";
  my $method = $self->can($meth_name)
    or die "no such method: $meth_name";

  # set default template and title
  $context->set_template("table/$meth_name.tt");
  $context->set_title($context->title . "-" . $table);

  # dispatch to method
  return $self->$method($table);
}


#----------------------------------------------------------------------
# published methods
#----------------------------------------------------------------------

sub descr {
  my ($self, $table) = @_;

  my $datasource = $self->datasource;
  my $descr      = $datasource->config(tables => $table => 'descr');

  # datastructure describing this table
  return {table       => $table, 
          colgroups   => $datasource->colgroups($table),
          primary_key => [$datasource->primary_key($table)],
          descr       => $descr};

}


sub list {
  my ($self, $table) = @_;

  my $context    = $self->context;
  my $req_data   = $context->req_data;
  my $datasource = $context->datasource;

  # the "message" arg is sent once from inserts/updates/deletes; not to
  # be repeated in links to other queries
  my $message = delete $req_data->{-message};

  # dashed args are set apart
  my %where_args  = %$req_data; # need a clone because of deletes below
  my %dashed_args = $context->view->default_dashed_args($context);
  foreach my $arg (grep {/^-/} keys %where_args) {
    $dashed_args{$arg} = delete $where_args{$arg};
  }

  # some dashed args are treated here (not sent to the SQL request)
  my $with_count = delete $dashed_args{-with_count};
  my $template   = delete $dashed_args{-template};
  $context->set_template($template) if $template;

  # select from database
  my $criteria  = $datasource->query_parser->parse(\%where_args) || {};
  my $statement = $datasource->schema->db_table($table)->select(
    -where => $criteria,
    %dashed_args,
    -result_as => 'statement',
   );
  my $rows         = $statement->select();

  # recuperate SQL for logging / informational purposes
  my ($sql, @bind) = $statement->sql;
  my $show_sql     = join " / ", $sql, @bind;
  $self->logger({level => 'debug', message => $show_sql});

  # assemble results
  my $data = $self->descr($table);
  $data->{rows}       = $rows;
  $data->{message}    = $message;
  $data->{criteria}   = $show_sql;
  if ($with_count) {
    $data->{row_count}  = $statement->row_count;
    $data->{page_count} = $statement->page_count;
  }

  # links to prev/next pages
  $self->_add_links_to_other_pages($data, $req_data,
                                   $dashed_args{-page_index},
                                   $dashed_args{-page_size});

  # link to update form
  $data->{where_args} = $self->_query_string(
    map { ("where.$_" => $where_args{$_}) } keys %where_args,
   );

  return $data;
}


sub _add_links_to_other_pages {
  my ($self, $data, $req_data, $page_index, $page_size) = @_;

  return unless defined $page_index && defined $page_size;

  $data->{page_index}    = $page_index;
  $data->{offset}        = ($page_index - 1) * $page_size + 1;
  $data->{similar_query} = $self->_query_string(%$req_data,
                                                -page_index => 1);
  $data->{next_page}     = $self->_query_string(%$req_data,
                                                -page_index => $page_index+1)
    unless @{$data->{rows}} < $page_size;
  $data->{prev_page}     = $self->_query_string(%$req_data,
                                                -page_index => $page_index-1)
    unless $page_index <= 1;
}



sub id {
  my ($self, $table) = @_;

  my $data = $self->descr($table);

  my $pk       = $data->{primary_key};
  my %is_pk    = map {($_ => 1)} @$pk;
  my @vals     = $self->context->extract_path_segments(scalar(@$pk));
  my %criteria = mesh @$pk, @vals;

  # get row from database
  my $row = $self->datasource->schema->db_table($table)->fetch(@vals);

  # assemble results
  $data->{row}    = $row;
  $data->{pk_val} = join "/", @vals;

  # links
  my %where_pk = map { ("where_pk.$_" => $criteria{$_}) } keys %criteria;
  $data->{delete_args} = $self->_query_string(%where_pk);
  $data->{update_args} = $self->_query_string(
    %where_pk,
    (map { ("curr.$_" => $row->{$_}) } grep {defined $row->{$_}} keys %$row),
   );
  my @clone_args = map  { ($_ => $row->{$_}) } 
                   grep {!$is_pk{$_} && defined $row->{$_}} keys %$row;
  $data->{clone_args} = $self->_query_string(@clone_args);

  return $data;
}


sub search {
  my ($self, $table) = @_;

  my $context  = $self->context;
  my $req_data = $context->req_data;

  if ($context->req->method eq 'POST') {
    my $output = delete $req_data->{-output} || "";
    my $cols   = [keys %{delete $req_data->{col} || {}}];
    $req_data->{-columns} = join ",", @$cols;
    $self->redirect("list$output?" . $self->_query_string(%$req_data));
  }
  else {
    # display the search form
    my @cols = split /,/, (delete $req_data->{-columns} || "");
    $req_data->{"col.$_"} = 1 foreach @cols;
    my $data = $self->descr($table);
    my $json_maker = JSON->new();
    $data->{init_form} = $json_maker->encode($req_data);
    return $data;
  }
}


sub update {
  my ($self, $table) = @_;

  my $context    = $self->context;
  my $req_data   = $context->req_data;
  my $datasource = $context->datasource;

  if ($context->req->method eq 'POST') {
    # columns to update
    my $to_set = $req_data->{set} || {};
    foreach my $key (keys %$to_set) {
      my $val = $to_set->{$key};
      delete $to_set->{$key} if ! length $val;
      $to_set->{$key} = undef if $val eq 'Null';
    }
    keys %$to_set or die "nothing to update";

    # filtering criteria
    my $where  = $req_data->{where} or die "update without any '-where' clause";
    my $criteria = $datasource->query_parser->parse($where);

    # perform the update
    my $db_table  = $datasource->schema->db_table($table);
    my $n_updates = $db_table->update(-set => $to_set, -where => $criteria);

    # redirect to a list to display the results
    my $message = ($n_updates == 1) ? "1 record was updated"
                                    : "$n_updates records were updated";
    # TODO: $message could repeat the $to_set pairs
    my $query_string = $self->_query_string(%$where, -message => $message);
    $self->redirect("list?$query_string");
  }
  else {
    # display the update form
    my $data = $self->descr($table);
    my $json_maker = JSON->new();
    if (my $where_pk  = delete $req_data->{where_pk}) {
      $data->{where_pk} = $where_pk;
      $req_data->{where} = $where_pk;
    };
    $data->{init_form} = $json_maker->encode($req_data);

    return $data;
  }
}


sub delete {
  my ($self, $table) = @_;

  my $context    = $self->context;
  my $req_data   = $context->req_data;
  my $datasource = $context->datasource;

  if ($context->req->method eq 'POST') {
    my $where = $req_data->{where} or die "delete without any '-where' clause";
    my $criteria = $datasource->query_parser->parse($where);

    # perform the delete
    my $db_table  = $datasource->schema->db_table($table);
    my $n_deletes = $db_table->delete(-where => $criteria);

    # redirect to a list to display the results
    my $message = ($n_deletes == 1) ? "1 record was deleted"
                                    : "$n_deletes records were deleted";
    my $query_string = $self->_query_string(%$where, -message => $message);
    $self->redirect("list?$query_string");
  }
  else {
    # display the delete form
    my $data = $self->descr($table);
    if (my $where_pk  = delete $req_data->{where_pk}) {
      $data->{where_pk}  = $where_pk;
      $req_data->{where} = $where_pk;
    };
    my $json_maker = JSON->new();
    $data->{init_form} = $json_maker->encode($req_data);

    return $data;
  }
}


sub insert {
  my ($self, $table) = @_;

  my $context    = $self->context;
  my $req_data   = $context->req_data;
  my $datasource = $context->datasource;

  if ($context->req->method eq 'POST') {
    # perform the insert
    my $db_table  = $datasource->schema->db_table($table);
    my @pk = $db_table->insert($req_data);

    # redirect to a list to display the results
    my $message = "1 record was inserted";
    my $query_string = $self->_query_string(-message => $message);
    $self->redirect(join("/", "id", @pk) . "?$query_string");
  }
  else {
    # display the insert form
    my $data = $self->descr($table);
    my $json_maker = JSON->new();
    $data->{init_form} = $json_maker->encode($req_data);

    return $data;
  }
}



#----------------------------------------------------------------------
# auxiliary methods
#----------------------------------------------------------------------


sub _query_string {
  my ($self, %params) = @_;
  my @fragments; 
 KEY:
  foreach my $key (sort keys %params) {
    my $val = $params{$key};
    length $val or next KEY;

    # cheap URI escape
    s/=/%3D/g, s/&/%26/g, s/;/%3B/g, s/\+/%2B/g for $key, $val;

    push @fragments, "$key=$val";
  }
  return join "&", @fragments;

  # TODO: decide about proper way to handle accented chars in URIs.
  # URI_escape did not work because of conflicts utf8/latin1
  # Hints : http://www.w3.org/International/articles/idn-and-iri/
  #         L<URI/as_iri>
}


1;

__END__

=head1 NAME

Plack::App::AutoCRUD::Controller::Table - Table controller

=head1 DESCRIPTION

This controller provides methods for searching and describing
a given table within some datasource.

=head1 METHODS

=head2 serve

Entry point to the controller; from the URL, it extracts the table
name and the name of the method to dispatch to (the URL is expected
to be of shape C<< table/{table_name}/{$method_name}?{arguments} >>).
It also sets the default template to C<< table/{method_name}.tt >>.

=head2 descr

Returns a hashref describing the table, with keys C<descr>
(description information from the config), C<table> (table name),
C<colgroups> (datastructure as returned from 
L<Plack::App::AutoCRUD::DataSource/colgroups>), and 
C<primary_key> (arrayref of primary key columns).

=head2 list

Returns a list of records from the table, corresponding to the query
parameters specified in the URL. 
[TODO: EXPLAIN MORE]





