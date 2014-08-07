use strict;
use warnings;

use Plack::Test;
use Test::More;
use HTTP::Request::Common;
use App::AutoCRUD;

use FindBin;


# setup config
my $sqlite_path = "$FindBin::Bin/data/"
                . "Chinook_Sqlite_AutoIncrementPKs_empty_tables.tst_sqlite";

my $connect_options = {
  RaiseError     => 1,
  sqlite_unicode => 1,
};
my $config = {
  app => { name => "Demo",
           title => "AutoCRUD demo application",
         },
  datasources => {
    Chinook => {
      dbh => {
        connect => ["dbi:SQLite:dbname=$sqlite_path", "", "", $connect_options],
      },
     },
   },
};


# instantiate the app
my $crud = App::AutoCRUD->new(config => $config);
my $app  = $crud->to_app;

# start testing
test_psgi $app, sub {
  my $cb = shift;

  # homepage
  my $res = $cb->(GET "/home");
  like $res->content, qr/AutoCRUD demo application/, "Title from config";
  like $res->content, qr/Chinook/,                   "Home contains Chinook datasource";

  # schema page
  $res = $cb->(GET "/Chinook/schema/tablegroups");
  like $res->content, qr/Artist/,                    "Artist listed";
  like $res->content, qr/Album/,                     "Album listed";
  like $res->content, qr/Track/,                     "Track listed";

  # table description
  $res = $cb->(GET "/Chinook/table/MediaType/descr");
  like $res->content, qr(INTEGER\s+NOT\s+NULL),      "MediaTypeId datatype";

  # search form (display)
  $res = $cb->(GET "/Chinook/table/MediaType/search");
  like $res->content, qr(<span class="TN_label colname pk">MediaTypeId</span>),
                                                     "MediaTypeId present, pk detected";

  # search form (POST)
  $res = $cb->(POST "/Chinook/table/MediaType/search");
  is $res->code, 302,                                "redirecting POST search";
  like $res->header('location'), qr/^list\?/,        "redirecting to 'list'";

  # list
  $res = $cb->(GET "/Chinook/table/MediaType/list?");
  like $res->content, qr(records 1 - 5),             "found 5 records";
  like $res->content, qr(MPEG),                      "found MPEG";
  like $res->content, qr(AAC),                       "found AAC";
  $res = $cb->(GET "/Chinook/table/MediaType/list?Name=*MPEG*");
  like $res->content, qr(LIKE \?),                   "SQL LIKE";
  like $res->content, qr(records 1 - 2),             "found 2 records";
  like $res->content, qr(Protected MPEG),            "found Protected MPEG";

  # TODO : test list outputs as xlsx, yaml, json, xml

  # TODO : test descr, update, insert, delete

};

# signal end of tests
done_testing;


