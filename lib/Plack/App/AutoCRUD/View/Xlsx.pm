package Plack::App::AutoCRUD::View::Xlsx;

use 5.010;
use strict;
use warnings;

use Moose;
extends 'Plack::App::AutoCRUD::View';

use Excel::Writer::XLSX;
use namespace::clean -except => 'meta';

sub render {
  my ($self, $data, $context) = @_;

  # pseudo-filehandle to memory buffer
  open my $fh, '>', \my $str 
    or die "Failed to open filehandle: $!";

  # open excel file in memory
  my $workbook  = Excel::Writer::XLSX->new($fh);
  my $worksheet = $workbook->add_worksheet();

  # initial Excel rows (title and select details)
  my $table   = $data->{table};
  my $title_fmt = $workbook->add_format(bold => 1, size => 13);
  my $sql_fmt   = $workbook->add_format(size => 9);
  $worksheet->write(0, 0, "Selection from $table", $title_fmt);
  $worksheet->write(1, 0, $data->{criteria}, $sql_fmt);

  # generate data table
  my $rows    = $data->{rows};
  my @headers = keys %{$rows->[0]};
  my $n_rows  = @$rows;
  my $n_cols  = @headers;
  $worksheet->add_table(2, 0, $n_rows + 1, $n_cols-1, {
    data    => [ map {[@{$_}{@headers}]} @$rows ],
    columns => [ map { {header => $_}} @headers ],
   });
  # TODO: add hyperlinks to records
  $workbook->close();

  # Plack response
  my @http_headers = (
    'Content-type'        => 'application/xlsx',
    'Content-disposition' => qq{attachment; filename="$table.xlsx"},
   );
  return [200, \@http_headers, [$str] ];
}

1;


__END__



