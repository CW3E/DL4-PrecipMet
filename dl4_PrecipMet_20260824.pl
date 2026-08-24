#! /usr/bin/perl
use constant FILE_NAME => "dl4_PrecipMet_20260824.pl ";
use constant DATE_MODIFIED => "24 Aug 2026"; 
#
#  Process DL4-PrecipMet firmware v1.0.0 binary data file and output CSV file
#                  
#  requires: inst_loc
#
#  The following functions are used in this program
#       OutputData()
#       readReleaseInfo()
#
#
# 30 Nov 2023 Douglas Alden
#   Program no longer tries to fill gaps between resets.

use Time::Local;
use constant { true => 1, false => 0 };
use Getopt::Std;


# Declare the perl command line flags/options we want to allow
my %options=();
getopts("dq", \%options);

my $siteNum, $siteName, $filename, $sensors, $stationElev;
my $latitude, $longitude, $startTime, $endTime;
my $sensor;

$RECORDSIZE = 1024;       	  # Number of bytes in a record in bin file
$BYTES_IN_HEADER = 16;        # Number of bytes in record used by header
$SAMPLES = 19;  
$SAMPLESIZE = 53;
$SAMPLE_INTERVAL = 60;        # Number of seconds between data points
$HEADERINT = $SAMPLE_INTERVAL * $SAMPLES;
$NAN = 'NaN';

if(scalar(@ARGV) < 1)
{
  print "\n" . FILE_NAME . " " . DATE_MODIFIED . " Douglas Alden CW3E\n";
  print "Usage: " . FILE_NAME . " -d -q DL4-XXXX <bin file>\n";
  print "       Options:\n";
  print "         -d  output header times\n";
  print "         -q  output data lines\n";
  print "       Needs files: <inst_loc> [all DL4 versions]\n";
  print "Note:  If program crashes prematurely check start and end times in inst_loc\n";
  print "       and check that bin file headers occur over the full deployment time.\n";
  print "\n";
  print "Description of inst_loc [used with all DL4 versions]\n";
  print "                            (if Capital NaN) \n";
  print "inst_loc: DL4-0006 sioPier01 rRB 10 33.4337 -117.1929 20031218232200 20040216190000 21 SIO_Pier\n";
  print "inst#    _|        |         ||| |  |       |         |              |              |  |\n";
  print "filename __________|         ||| |  |       |         |              |              |  |\n";
  print "TB0      ____________________||| |  |       |         |              |              |  |\n";
  print "TB1      ____________________||| |  |       |         |              |              |  |\n";
  print "battery  ______________________| |  |       |         |              |              |  |\n";
  print "statElev ________________________|  |       |         |              |              |  |\n";
  print "Lat      ___________________________|       |         |              |              |  |\n";
  print "Lon      ___________________________________|         |              |              |  |\n";
  print "starttime_____________________________________________|              |              |  |\n";
  print "endtime  ____________________________________________________________|              |  |\n";
  print "siteNum  ___________________________________________________________________________|  |\n";
  print "siteName \(use _ between words as required\) ____________________________________________|\n";

  exit;
}

if(defined $options{d}) { print "-d Output header times\n"; $DEBUG = 1;}
if(defined $options{q}) { print "-q Output data line\n"; $QUIET = 0;}

open(BINFILE, "$ARGV[1]") || die "No input file specified \n";
print FILE_NAME . "\nProcessing $ARGV[1] @DEBUG\n\n";

$ARGV[0] = uc $ARGV[0];  # convert to upper case

($siteNum, $siteName, $filename, $sensors, $stationElev, $latitude, $longitude, $startTime, $endTime) = readReleaseInf( $ARGV[0] );
@sensor = split(/ */,$sensors);

$sensorFlag = SensorFlags(@sensor, $sensorFlag);

($Sc, $Mn, $Hr, $Dy, $Mo, $currentYr) = gmtime($startTime);

my $recordNumber = 0;
my $firstHeaderRead = 0;
my $countOfBlankRecords = 0;   # used to confirm we have not just hit a gap in the file
my $precip0_last = 0;              # precip0 total for previous minute
my $precip1_last = 0;              # precip1 total for previous minute

my @timeStamp = ();
my @hourTimeStamp = ();
my @data = ();
my @hourData = ();

# Create a status log that prints out headers whenever data logging is
# is (re)started.
open(STATUSFILE, ">status.log") || die "No input file specified \n";
print "Processing and reset information written to status.log\n";
printf STATUSFILE "\n" . FILE_NAME . " " . DATE_MODIFIED . " Spencer Kawamoto/Douglas Alden\n\n";
printf STATUSFILE "Input: $ARGV[1]\n";
printf STATUSFILE "Output: $filename\n";

# Send inst_loc info to status file
printf STATUSFILE "Site Name              : $siteName\n";
printf STATUSFILE "Site #                 : $siteNum\n";
printf STATUSFILE "Station Elevation (m)  : $stationElev\n";
printf STATUSFILE "Location: $latitude  $longitude\n";

@bytes = ();  # Truncate bytes array down to nothing before filling

# Skip any blank records at the beginning of the bin file. 
# A full record is 1024 bytes but sometimes the first full record does not
# align with the start of bin file. Therefore, read in the 512 bytes of data
# at a time and check if it is empty. If it is empty, keep reading 512
# byte chunks until the first header is found.
my $blank512 = 0;
my $firstRecordHasBeenFound = 0;
printf "\nLooking for first header in bin file...\n";
while (!$firstRecordHasBeenFound)
{
   seek(BINFILE, $blank512, 0) or die "Seek failed: $!"; # Set file position to start + number of bytes in $blank512
   my $bytes_read = read(BINFILE, $record, 512);
   die "Cannot read file or EOF reached\n" unless defined $bytes_read && $bytes_read == 512;
   
  # Skip only blocks that are entirely erased (all bytes are 0xFF).
  if($record eq "\xFF" x 512)
   {
      $blank512 += 512;
   }
   else # Header has been found
   {
      $firstRecordHasBeenFound = 1;
      printf "Header found at byte offset 0x%0X\nBegin data processing\n\n",$blank512;
      $recordNumber = 0;
      sleep 2;
   }
}

$readResult = false;
$stopProcessing = false;

while (seek(BINFILE, $recordNumber * $RECORDSIZE + $blank512, 0) && $stopProcessing==false)
{

  $recordNumber++;

  $readResult = read(BINFILE, $record, $RECORDSIZE);
  # Check if at least one header has been read and program has reached the end of
  # the file or did not read a full record
  if( ($firstHeaderRead == 1) && ( ( $readResult == 0 ) || ( $readResult < $RECORDSIZE ) ) )
  {
    if ( CheckFirmwareVersion($firmwareVersion) )
    {
      OutputData($filename, $stationElev, $sensorFlag, @data);
    }
    die "End of data records reached.  No more data to process\n";
  }
  else
  {
    #
    # split record into individual bytes and unpack as unsigned characters
    #
    @bytes = ();  # Truncate bytes array down to nothing before refilling
    @bytes = unpack("C*", $record);

    # Only output data if the block is not FF. We look at byte 1 because byte 0
	  # is sometimes 0 even though the rest of the block is all FF.
    $str = pack("C*", @bytes); # convert the array to a string
    $len = scalar(@bytes); # get the length of the array
    $all_FF = ($str eq "\xFF" x $len); # compare the string with a string of 0xFF repeated $len times

    if( !($all_FF) )
    {
      # Read header from record
      # Year is not read from header since it contains diagnostic information
      # in the tens digit, year from start time in inst_loc is used instead
      #
      $instNum =  BCDtoDec( $bytes[0] ) * 100  + BCDtoDec( $bytes[1] );
      $Yr = BCDtoDec($bytes[2]) * 100 + BCDtoDec( $bytes[3] );
      $Mo = BCDtoDec($bytes[4]);
      $Dy = BCDtoDec($bytes[5]);
      $Hour = BCDtoDec($bytes[6]);
      $Mn = BCDtoDec($bytes[7]); 
      $Sc = BCDtoDec($bytes[8]);

      $BattV = ( ($bytes[9] & 0x0F ) << 8 ) | $bytes[10];
      if(@sensor[3] eq "2")
      {
        # R = 200k   (3 * 240.2) / (4095 * 40.2) = 0.00437738
        $BattV = $BattV * 0.00437738;
      }
      else
      {
        # R = 324k   (3 * 364.2) / (4095 * 40.2) =
        $BattV = $BattV * 0.00663714;
      }
      $firmwareVersion = $bytes[11];	# Firmware Version(CODE_VERSION)
      $systemClockLost = $bytes[12];	# System was started without a known clock
    
      $tx_fletcherChkSum = ( $bytes[13] << 8 ) | $bytes[14];  # Fletcher Checksum
      # Set bytes 13 and 14 of the record to zero before we compute the checksum
      # as this was the state they were in when checksum was computed on datalogger
      $byte13 = @bytes[13];
      $byte14 = @bytes[14];
      $bytes[13] = $bytes[14] = 0;

      # Compute Checksum
      $c0 = $c1 = 0;
      #foreach $byte (@bytes)
      for($ii = 0; $ii < $RECORDSIZE; $ii++)
      {
        $c0 = ($c0 + @bytes[$ii]) & 0xFF;
        $c1 = ($c1 + $c0) & 0xFF;
      }  
        
      $fletcherChkSum = ( ( ($c0 - $c1) & 0xFF ) << 8) + ( ($c1 - (2 * $c0)) & 0xFF);
      if($fletcherChkSum == $tx_fletcherChkSum)
      { # checksum is valid
        $chkSum = 'OK';
      }
      else { $chkSum = 'BAD'; }
      
      $headerTimeStamp = timegm($Sc,$Mn,$Hour,$Dy,$Mo-1,$Yr-1900);

      # Ignore records with a header outside this deployment's time window.
      next if ($headerTimeStamp < $startTime || $headerTimeStamp > $endTime);
      
      $firstHeaderRead = 1;
    
      if ($DEBUG)
      {
 
          if (!$QUIET)
          {
            printf ("%04d %04d-%02d-%02d %02d:%02d:%02d %1d %3.1f %s", 
              $instNum, $Yr, $Mo, $Dy, $Hour, $Mn, $Sc, $systemClockLost, $BattV, $chkSum);
            printf (" %4.2f %4.2f  %4.2f %4.2f\n", $precip0, $precip0_Min, $precip1, $precip1_Min);
          }
          else
          {
            printf ("%04d %04d-%02d-%02d %02d:%02d:%02d %1d %3.1f %s\n", 
              $instNum, $Yr, $Mo, $Dy, $Hour, $Mn, $Sc, $systemClockLost, $BattV, $chkSum);
          }
      }
    
      #
      # Loop through the data and if it occurs between start and end time
      # convert the value to engineering units and push onto an array
      #
      for(my $i=0, $wOffset=$BYTES_IN_HEADER; $i<$SAMPLES; $i++, $wOffset=$wOffset+$SAMPLESIZE)
      {
        if(($headerTimeStamp >= $startTime) && ($headerTimeStamp <= $endTime))
        {
          ($sec, $min, $hour, $day, $mon, $year) = gmtime($headerTimeStamp);
          
          @array = @bytes[$wOffset..($wOffset+$SAMPLESIZE-1)];  # get all the bytes in this record
          $str = pack("C*", @array); # convert the array to a string
          $len = scalar(@array); # get the length of the array
          $all_FF = ($str eq "\xFF" x $len); # compare the string with a string of 0xFF repeated $len times

          if(!$all_FF)  # there is data in this record, so process it
          {
            # Rainfall 0 (in)
            if(@sensor[0] eq "r")
            {
              $precip0 =  ( ( $bytes[$wOffset + 22] ) << 8 ) + $bytes[$wOffset + 23];
              if($precip0 != 65535) # some data was recorded
              { 
                $precip0 *= 0.01;  # Convert to in of rainfall
                # Calculate precip measured in last minute
                $precip0_Min = $precip0 - $precip0_last;
                if($precip0_Min < 0) { $precip0_Min = 0; }
                $precip0_last = $precip0;
              }
              else { $precip0 = $NAN; $precip0_Min = $NAN; }
            }
            else{$precip0 = $NAN; $precip0_Min = $NAN;}
          
            # Rainfall 1 (in)
            if(@sensor[1] eq "r")
            {
              $precip1 =  ( ( $bytes[$wOffset + 24] ) << 8 ) + $bytes[$wOffset + 25];
              if($precip1 != 65535)
              {
                $precip1 *= 0.01;  # Convert to in of rainfall
                # If logger reset during deployment we need to add on the last
                # recorded value before the reset occurred.
                $precip1_Min = $precip1 - $precip1_last;
                if($precip1_Min < 0) { $precip1_Min = 0; }
                $precip1_last = $precip1;
              }
              else { $precip1 = $NAN; $precip1_Min = $NAN}
            }
            else {$precip1 = $NAN; $precip1_Min = $NAN;}
          
            ####Minute data section
            #                     Date                          ID SF BV   P0   P0M  P1   P1M
            $dataline = sprintf ("%04d-%02d-%02d %02d:%02d:%02d,%d,%X,%.2f,%.2f,%.2f,%.2f,%.2f\n",
              $year+1900, $mon+1, $day, $hour, $min, $sec, $instNum, $sensorFlag, 
              $BattV, $precip0, $precip0_Min, $precip1, $precip1_Min);
          
            push(@timeStamp, $headerTimeStamp);
            push(@data, $dataline);
            ##End Minute Data Section
          }
        } # END if(($headerTimeStamp >= $startTime) ...
        $headerTimeStamp += $SAMPLE_INTERVAL;
          
        #
        # If we have read past the end time stop reading the file
        #
        if($headerTimeStamp > $endTime)
        {
          $i = $SAMPLES;          # This will cause the for($i=0... to end
          $stopProcessing = true;
        }
      } # END for($i=0, $wOffset=$BYTES_IN...
    } # END if( !($bytes[0] == 0xFF) )
    elsif( ($firstHeaderRead == 1) && ($bytes[3] == 0xFF) )
    {
      if($countOfBlankRecords++ == 10 )
         { $stopProcessing = true; } # We have reached the blank data at the end of the file
    }
  }

} # while (<BINFILE>)

close(BINFILE);

print "\nSite Name: $siteName\n";
print "Site #:    $siteNum\n";

($Sc, $Mn, $Hr, $Dy, $Mo, $Yr) = gmtime($timeStamp[0]);
printf "Start time: %4d-%02d-%02d %02d:%02d\n", $Yr+1900, $Mo+1, $Dy, $Hr, $Mn;
($Sc, $Mn, $Hr, $Dy, $Mo, $Yr) = gmtime($timeStamp[-1]);   # last element of $timeStamp
printf "End time: %4d-%02d-%02d %02d:%02d\n", $Yr+1900, $Mo+1, $Dy, $Hr, $Mn;
# Print end time to status log
printf STATUSFILE "%4d-%02d-%02d %02d:%02d  End of time series\n", $Yr+1900, $Mo+1, $Dy, $Hr, $Mn;

#
# Output data is CSV format
#
if( CheckFirmwareVersion($firmwareVersion) )
{
  OutputData($filename, $stationElev, @data);
}


#####
#
# CheckFirmwareVersion
#
#
####
sub CheckFirmwareVersion
{
  my $firmwareVersion = @_[0];
  my $message = "";
  my $okToOutput = true;
  if($firmwareVersion <= 0x89)
  {
    sprintf $message, "FIRMWARE VERSION: Do not process data generated with this firmware with this program: %02X\n", $firmwareVersion;
    #$okToOutput = false;
  }
  elsif($firmwareVersion == 0x96){ $message = "FIRMWARE VERSION: DL4-PrecipMet v1.0.0\n"; }
  
  else{ $message = "FIRMWARE VERSION: Not Available\n";}
  print $message;
  print STATUSFILE $message;

  close(STATUSFILE);
  
  return $okToOutput;
}

#####
#
# OutputData
#
####
sub OutputData
{
  my ($filename, $stationElev, $sensorFlag, $data) = @_;

  my ($outputFile);

	$numberOfPoints = scalar(@data);
  
  if($numberOfPoints > 1)
	{
		$outputFile = sprintf("%sm_raw.csv", $filename);
		print "Output to: $outputFile\n\n";
		open(OUTPUT, "> $outputFile") || die "Can't open output file\n";
	
		#
		# Print 5 lines of header information to output file
		#
		print OUTPUT "siteNum,siteName,station_elev,lat,lon\n";
        print OUTPUT "#,string,meters,deg,deg\n";
        printf OUTPUT "%d,%s,%d,%.4f,%.4f\n",
					 $siteNum, $siteName, $stationElev, $latitude, $longitude;
		print OUTPUT "Date,InstID,SensorFlag,BattV,Precip0,Precip0_Min,Precip1,Precip1_Min\n";
		print OUTPUT "YYYY-MM-DD HH:MM,#,hex,V,in,in,in,in\n";
	
		#
		# Print out data array to file
		#
    foreach(@data)
      { print OUTPUT "$_"; }
	
		close(OUTPUT);
	}
}

#####
#
# BCDtoDec - Convert a BCD number to a base 10 decimal number
#
#####
sub BCDtoDec
{
  my ($bcd) = $_[0];
  my ($decimal, $temp);

  # Get tens column
  $decimal = ($bcd & 0xF0) >> 4;
  $decimal *= 10;

  # Add ones column
  $decimal += ($bcd & 0x0F);
  
  return($decimal);
}

#####
#
# Read info on deployment and recovery from inst_loc
#
#####
sub readReleaseInf
{
  my ($instNum) = $_[0];
  my ($found, $siteNum, $siteName, $filename, @sensors, $stationElev);
  my ($not_used, $latitude, $longitude);
  my ($deployTime, $recoveryTime, @value);
  my ($Yr, $Mo, $Dy, $Hr, $Mn, $Sc); my ($i);
  my ($PI);

  local *fileHandle;

  open(fileHandle, "inst_loc") || die "Cannot open inst_loc file\n";

  $found = 0;
  while (<fileHandle>)
  {
    chop($_);
    $_ =~ s/^[ ]+//; # kill any leading white space
    @value = split(/\s+/, $_);

    if (uc($value[0]) eq $instNum)
    {
      $filename = $value[1];
      $sensors = $value[2];

      $stationElev = $value[3];

      $latitude = $value[4];
      $longitude = $value[5];
      
      $Yr = substr($value[ 6],0,4);
      $Mo = substr($value[ 6],4,2);
      $Dy = substr($value[ 6],6,2);
      $Hr = substr($value[ 6],8,2);
      $Mn = substr($value[ 6],10,2);
      $Sc = substr($value[ 6],12,2);
     
      $deployTime = timegm(0,$Mn,$Hr,$Dy,$Mo-1,$Yr);

      $Yr = substr($value[ 7],0,4);
      $Mo = substr($value[ 7],4,2);
      $Dy = substr($value[ 7],6,2);
      $Hr = substr($value[ 7],8,2);
      $Mn = substr($value[ 7],10,2);
      $Sc = substr($value[ 7],12,2);

      $recoveryTime = timegm(0,$Mn,$Hr,$Dy,$Mo-1,$Yr);

      $siteNum = $value[8];
      $siteName = $value[9];
      $siteName =~ tr/_/ /;

      # print out data from inst_loc
      print "Site Name              : $siteName\n";
      print "Site #                 : $siteNum\n";
      print "Station Elevation (m)  : $stationElev\n";
      print "Location: $latitude  $longitude\n";
      #print "inst_loc starttime: $value[6]\n";
      #print "inst_loc endtime:   $value[7]\n";
      print "\n";

      $found = 1;
      last;     # stop when match is found
    }
  }
  if ( $found == 0 ) { die "Cannot find data for release $instNum\n"; }
  close(fileHandle);
		      
    return ($siteNum, $siteName, $filename, $sensors, $stationElev,
      $latitude, $longitude, $deployTime, $recoveryTime);
}

sub SensorFlags
{
  my (@sensor, $sensorFlag) = @_;
  
  if(@sensor[0] eq "r") # TB0
  {
    $sensorFlag |= 0x0080;
  }
  if(@sensor[1] eq "r") # TB1
  {
    $sensorFlag |= 0x0100;
  }
  
  return($sensorFlag);
}
