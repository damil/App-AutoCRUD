use strict;
use warnings;
use LWP::Simple;

print STDERR "downloading sakila ...";
mirror(
  "http://sakila-sample-database-ports.googlecode.com/svn/trunk/ sakila-sample-database-ports/sqlite-sakila-db/sqlite-sakila.sq",
  "sakila.sqlite"
);
print STDERR "done\n";




