#!/usr/bin/perl
#
# Written by John Jones (johnnwvs@gmail.com) in 2012 and updated every so often.
# To pull driving distance data between two locations from Google.
# I may have pulled some code from elsewhere, but I cannot remember if I completely re-invented the wheel or not.

use LWP::Simple;
use HTML::Parse;
#use XML::Parser;

package google_dirs;
sub new
{
  my $class = shift;
  my $self = {
     _start_addr => shift,
     _end_addr   => shift,
     _distance   => shift,
     _duration   => shift,
     _start_lat  => shift,
     _start_long => shift,
     _end_lat    => shift,
     _end_long   => shift
  };
}
my $google_dirs_obj = new google_dirs;


package original_file;
sub new
{
  my $class = shift;
  my $self = {
     _ID          => shift,
     _ptaddr1     => shift,
     _ptaddr2     => shift,
     _ptzip       => shift,
     _ptcnty      => shift,
     _proaddr1    => shift,
     _proaddr2    => shift,
     _prozip      => shift,
     _procnty     => shift,
     _hpsa        => shift
  };
}
my $orig_file_obj = new original_file;

#remove tags ( <> chars )
sub remove_html_tags
{
  my $string = $_[0];
  my $init_string="";

 $init_string=substr($string, index($string, '>'), 80);
 return(substr($init_string, 1, index($init_string, '<')-1));
}

sub read_csv_line
{
  my $line=$_[0];
  my @cells;

    sub csvsplit
    {
        my $line = shift;
        my $sep = (shift or ',');

        return () unless $line;

        my @cells;
        $line =~ s/\r?\n$//;

        my $re = qr/(?:^|$sep)(?:"([^"]*)"|([^$sep]*))/;

        while($line =~ /$re/g) {
                my $value = defined $1 ? $1 : $2;
                push @cells, (defined $value ? $value : '');
        }

        return @cells;
    }

  @cells = csvsplit($_);

  # example read in csv text: XXXX Beaumont Dr Greenville NC 27858 XXXX Moye Blvd Greenville NC 27834
  return @cells;
}

sub get_data_from_google
{
  # Read url in to the $url variable
#  my $url = 'http://maps.googleapis.com/maps/api/directions/xml?origin=Greenville,+NC&destination= Wilmington,+nc&sensor=false';
  my $url = $_[0];

  # set user agent (browser), if needed
  my $ua = new LWP::UserAgent;
  $ua->timeout(15); # set timeout

  my $request = HTTP::Request->new('GET');
  $request->url($url);

  my $response = $ua->request($request); # get response from web server
  # my $code = $response->code; # extract response code, if needed

  my $headers = $response->headers_as_string;
  my $body = $response->content;

  #my $parsed_html = HTML::Parse::parse_html($body);
  #print "$body\n";

  my @body_arr = split "\n", $body; # split the multiline string up to lines in an array

  #my $prev1="", $prev2="";

  foreach (@body_arr)
  {
    if ($_ =~ m/OVER_QUERY_LIMIT/i) {
      print "Error, cannot process url: $url\n";
      print "Google output: $_\n";
      print "OVER GOOGLE QUERY LIMIT, delaying before trying again.\n";
      return 0; # no more addresses can be processed, return an error.
    }
    if ( ($prev1 =~ m/start_location/i) && (!($google_dirs_obj->{_start_lat})) ) {
      $google_dirs_obj->{_start_lat} = remove_html_tags($_);
      # print "setting start lat = $_\n";
    }

    if ( ($prev2 =~ m/start_location/i) && (!($google_dirs_obj->{_start_long})) ) {
      $google_dirs_obj->{_start_long} = remove_html_tags($_);
      # print "setting start long = $_\n";
    }

    if ($_ =~ m/start_address/i) {
      $google_dirs_obj->{_start_address} = remove_html_tags($_);
      # print "setting start address = $_\n";
    }

    if ($_ =~ m/end_address/i) {
      $google_dirs_obj->{_end_address} = remove_html_tags($_);
      # print "setting end address = $_\n";
    }

    if ($prev1 =~ m/<distance/i) {
      $google_dirs_obj->{_distance} = remove_html_tags($_);
      # print "setting distance in meters, last iteration is full distance = $_\n";
    }

    if ($prev1 =~ m/<duration/i) {
      $google_dirs_obj->{_duration} = remove_html_tags($_);
      # print "setting duration in seconds, last iteration is total duration = $_\n";
    }


    #  print "$_\n";

    $prev2=$prev1;
    $prev1=$_;
  } 
  return 1;
}

sub parse_source_addr
{
  my @raw_addr=@_;
  my $zipcode=@raw_addr[7];
  my $county = @raw_addr[8];
  $/ = "\r"; # change the input record separator (IRS) to match the Windows EOL for chomp
  chomp $county; # remove the end-of-line from the last field
  # if ($zipcode =~ m/-/i) {
  #   my $zipcode=substr($zipcode,0,index($zipcode,'-'));
  # }
  $zipcode=substr($zipcode,0,5); # pull only the first 5 digits of a zip code
  my @source_addr = "@raw_addr[5] + @raw_addr[6] + $zipcode + $county + NC";
  return @source_addr;
}

sub parse_dest_addr
{
  my @raw_addr=@_;
  my $zipcode=@raw_addr[3];
  my $county = @raw_addr[4];
  #  if ($zipcode =~ m/-/i) {
  #    $zipcode=substr($zipcode,0,index($zipcode,'-'));
  #  }
  $zipcode=substr($zipcode,0,5); # pull only the first 5 digits of a zip code
  my @dest_addr = "@raw_addr[1] + @raw_addr[2] + $zipcode + $county + NC";
  return @dest_addr;
}

sub fill_original_addr
{
  my @raw_addr=@_;
  $orig_addr_obj->{'_ID'} = @raw_addr[0];
  $orig_addr_obj->{'_ptaddr1'} = @raw_addr[1];
  $orig_addr_obj->{'_ptaddr2'} = @raw_addr[2];
  $orig_addr_obj->{'_ptzip'} = @raw_addr[3];
  $orig_addr_obj->{'_ptcnty'} = @raw_addr[4];
  $orig_addr_obj->{'_provaddr1'} = @raw_addr[5];
  $orig_addr_obj->{'_provaddr2'} = @raw_addr[6];
  $orig_addr_obj->{'_provzip'} = @raw_addr[7];
  $orig_addr_obj->{'_provcnty'} = @raw_addr[8];
  $/ = "\r"; # change the input record separator (IRS) to match the Windows EOL for chomp
  chomp @raw_addr[9]; # remove the end-of-line from the last field
  $orig_addr_obj->{'_hpsa'} = @raw_addr[9];
}


sub output_to_csv
{
  my $outfilename = $_[0];
  my $skip_header = $_[1];
  open (CSVOUT, ">>$outfilename") or die $!;
  if (!($skip_header)) # output the header only once
  {
    print CSVOUT "ID,PTADDR1,PTADDR2,PTZIP,PTCNTY,PROVADDR1,PROVADDR2,PROVZIP,PROVCNTY,HPSA,";
    print CSVOUT "G_START_LAT,G_START_LONG,G_DISTANCE,G_DURATION,";
    print CSVOUT "G_START_ADDR1,G_START_ADDR2,G_START_ADDR3,G_START_ADDR4,G_END_ADDR1,G_END_ADDR2,";
    print CSVOUT "G_END_ADDR3,G_END_ADDR4\n";
  }
  else
  {
    print CSVOUT "$orig_addr_obj->{_ID},";
    print CSVOUT "$orig_addr_obj->{_ptaddr1},";
    print CSVOUT "$orig_addr_obj->{_ptaddr2},";
    print CSVOUT "$orig_addr_obj->{_ptzip},";
    print CSVOUT "$orig_addr_obj->{_ptcnty},";
    print CSVOUT "$orig_addr_obj->{_provaddr1},";
    print CSVOUT "$orig_addr_obj->{_provaddr2},";
    print CSVOUT "$orig_addr_obj->{_provzip},";
    print CSVOUT "$orig_addr_obj->{_provcnty},";
    print CSVOUT "$orig_addr_obj->{_hpsa},";

    print CSVOUT "$google_dirs_obj->{_start_lat},";
    print CSVOUT "$google_dirs_obj->{_start_long},";
    print CSVOUT "$google_dirs_obj->{_distance},";
    print CSVOUT "$google_dirs_obj->{_duration},";

    print CSVOUT "$google_dirs_obj->{_start_address},";
    print CSVOUT "$google_dirs_obj->{_end_address}\n"; # keep newline for the last entry of each line
  }  
  close(CSVOUT);
}

#### MAIN ####
  my $filename=$ARGV[0];
  my $skiplines=$ARGV[1];
  my $outfilename="processed_address_file.csv";
  my @all_raw_addr;
  my $skip_header=0;
  my $max_run=0;
  use POSIX qw(strftime);
  my $date= strftime('%Y/%m/%d %H:%M:%S', localtime);
  $|++; # output everything right away


  print "Processing $filename and outputting to $outfilename\n";
  print "on $date\n";
  if ($skiplines)
  { print "skipping $skiplines lines.\n"; }

  print "Warning: if $outfilename already exists, it will be appended to\n";

  $/ = "\r";
  open (CSV, "<", $filename) or die $!;
  #while ( (<CSV>) && ($max_run < 3) )
  while (<CSV>)
  {
    my $rerun=0;
    $max_run++;
    @all_raw_addr=read_csv_line($_); # read in the raw address from the CSV file
    fill_original_addr(@all_raw_addr); # Fill in the original address object, so it can be written back to file
    if ($skiplines)
    {
      if ($max_run < $skiplines)
      {
        print "Skipping ID $orig_addr_obj->{_ID}, run: $max_run\n";
        next;
      }
    }
    my @parsed_source_addr=parse_source_addr(@all_raw_addr);
    my @parsed_dest_addr=parse_dest_addr(@all_raw_addr);

    my $url = "http://maps.googleapis.com/maps/api/directions/xml?origin=@parsed_source_addr&";
    $url   .= "destination= @parsed_dest_addr&sensor=false";
    if ($skip_header)
    {
      select(undef, undef, undef, 0.250); # sleep for a very brief time, 250 milliseconds so google does not stop us
      while (!get_data_from_google($url))
      {
         sleep 5;
         if ($rerun>9)  # try running query again after delay, up to 10 times
         { 
           print "Over the limit for Google queries today, try running program later.\n";
           exit 0; #exit program if delay does not work
         }
         $rerun++;
      }
      $rerun=0; # reset rerun after successful run
      output_to_csv($outfilename,$skip_header);
      if (0) # print out the contents of the object, 0 to skip display, 1 to display
      {
        print "URL: $url\n";
        print "source addr: @parsed_source_addr\n";
        print "dest   addr: @parsed_dest_addr\n";
        print "content of google directions object:\n";
        print "Start addr:          $google_dirs_obj->{_start_address}\n";
        print "End addr:            $google_dirs_obj->{_end_address}\n";
        print "Start lat:           $google_dirs_obj->{_start_lat}\n";
        print "Start long:          $google_dirs_obj->{_start_long}\n";
        print "Distance (meters):   $google_dirs_obj->{_distance}\n";
        print "Duration (secs):     $google_dirs_obj->{_duration}\n";

        print "Orig addr    ID:          $orig_addr_obj->{_ID}\n";
        print "Orig addr     1:          $orig_addr_obj->{_ptaddr1}\n";
        print "Orig addr     2:          $orig_addr_obj->{_ptaddr2}\n";
        print "Orig addr   zip:          $orig_addr_obj->{_ptzip}\n";
        print "Orig addr  cnty:          $orig_addr_obj->{_ptcnty}\n";
        print "Orig addr padr1:          $orig_addr_obj->{_provaddr1}\n";
        print "Orig addr padr2:          $orig_addr_obj->{_provaddr2}\n";
        print "Orig addr  pzip:          $orig_addr_obj->{_provzip}\n";
        print "Orig addr pcnty:          $orig_addr_obj->{_provcnty}\n";
        print "Orig addr  hpsa:          $orig_addr_obj->{_hpsa}\n";
      }
    }
    else
    { output_to_csv($outfilename,$skip_header); }
    $skip_header=1; # only skip the header
    if (($max_run % 100) == 0)
    { print "Processing line # $max_run\n"; }
  }

  my $date= strftime('%Y/%m/%d %H:%M:%S', localtime);
  print "Program run completed at $date\n"; 

