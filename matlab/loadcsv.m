%   LOADCSV        Loads csa files and returns data in a structure
%
%   X = LOADCSV(FILENAME); returns a data structure to variable X 
%
%   X = LOADCSV(FILENAME,SAVEFILE); saves a data structure named X in the 
%   matfile named SAVEFILE. The data structure is also assigned to X in
%   this line. 
%
%   X = LOADCSV;  If FILENAME is missing, the user is prompted for 
%      an input filename, and an output file to save the structure.
%      Note that assignment value X is optional as well.
%
%   X is 1x5 struct array with fields:
%	   filename 		Name of file you entered
%	   hdr_startdate	start date, 14 digit string yyyyMMddhhmmss
%	   npts			    Number of points
%	   samp_int		    sample interval
%	   starttime    	Startdate as matlab datetime
%	   endtime  		Endtime as matlab datetime
%	   times			Array of data timestamps in matlab datetime format
%	   elev             elevation above (+) or below (-) sea level
%	   lat			    latitude
%	   lon			    longitude
%	   datatype		    data type (for example north east temp pres ...)
%	   dataunits		data units (for example m_s deg_C ...)
%	   Data			    Array of data
%
%   Brett Lesh
%   Center For Coastal Studies  11/1/2000
%
%   Douglas Alden
%	17 Sep 2001 added y2k compliance with 14 digit dates
%   
%   Douglas Alden
%   17 May 2011
%       - added ability to save file as .mat
%       - prompts user to open filename if none is given
%       - saves data as X.data(i) instead of X(i).data
%
%   Douglas Alden
%   17 May 2012
%       - close the data file at end of script
%
%   Douglas Alden
%   08 Oct 2018
%       - revised to use datetime instead of datenum for dates
%       - added reading full path when file is selected
%
%   Douglas Alden
%   01 May 2020
%       - Changed file read with fscanf to readtable. This sped up data
%         loading by a factor of 10 or more.
%
%   Douglas Alden
%   01 May 2020
%       - Changed X.depth to X.elev
%   Douglas Alden
%   17 Oct 2020
%       - Added more options: 'Delimiter','\t','MultipleDelimsAsOne',true
%       - to readtable
%   Douglas Alden
%   15 Sep 2023
%       - Changed name to LOADCSV.m
%       - Changed delimiter from '\t; to 'WhiteSpace' when reading
%         data lines
%       - Added line to rename data column names using data type
%         X.data.Properties.VariableNames = X.datatype;

%   Charlotte Piazza
%   22 Sep 2023
%       - copied and changed name to loadcsvData.m
%       - reworked the way data is read from the header to work with new
%         csv format
%
%   Douglas Alden
%   26 Sep 2023
%       - updated to generate and save data as timetable including metadata
%         on site info.
%
%   Douglas Alden
%   03 October 2023
%       - time is read for date column rather than calculating it from the
%         number of points.  Gaps are filled with NaNs
%
%   Douglas Alden
%   08 October 2023
%       - Added UTC timezone to X
%
%
%   Charlotte Piazza
%   11 November 2023
%       - Fixed a bug where data with logger resets wasn't being read right
%
%   Charlotte Piazza
%   20 November 2023
%       - Added "X.Time.Format = 'yyyy-MM-dd HH:mm:ss'" to make sure time
%       is formatted correctly as datetime format was inconsistent between 
%       final csv and mat files

function X = loadcsv(filename,savefile)


currentFolder = pwd;
% Check number of input arguments - if none, prompt for file selection
if (nargin == 0)
    [filename, folder] = uigetfile('*.csa; *.csv','LOADCSV: Select file');   
    if isnumeric(filename)
        fprintf('LOADCSV file selection cancelled\n');
        X = [];
        return
    end
    fullfilename = fullfile(folder, filename);
else
    folder = currentFolder;
end

fullfilename = fullfile(folder, filename);
[filepath,name,ext] = fileparts(filename);

fid= fopen(fullfilename);
line1= fgetl(fid); % metadata type
line2= fgetl(fid); % metadata units

%% Read Deployment Info
deployinfo = textscan(fgetl(fid), '%s', 'Delimiter',',');
deployinfo = deployinfo{1}';
fclose(fid);  % close the data file


%%  Read data and create timetable
opts = detectImportOptions(filename);
opts.VariableNamesLine = 4;
opts.VariableUnitsLine = 5;
data = readtable(filename, opts);

X = table2timetable(data,'RowTimes','Date');
X.Properties.DimensionNames{1} = 'Time';

% Set time step %%don't do this, it retimes the table incorrectly and
% overwrites the actual recorded times
dt = X.Time(2) - X.Time(1);

% Add custom properties with site metadata
X = addprop(X,{'SourceFile','SiteNum','SiteName','Elev', ...
                               'Latitude','Longitude'}, ...
                               {'table','table','table','table','table','table'});

X.Time.TimeZone = 'UTC';
X.Time.Format = 'yyyy-MM-dd HH:mm:ss';

% Source File
X.Properties.CustomProperties.SourceFile = filename;
% Site Number
X.Properties.CustomProperties.SiteNum = str2num(deployinfo{1});
% Site Name
X.Properties.CustomProperties.SiteName = strrep(deployinfo{2},"_"," ");
% Elevation
X.Properties.CustomProperties.Elev = str2double(deployinfo{3});
% Latitude
X.Properties.CustomProperties.Latitude = str2double(deployinfo{4});
% Longitude
X.Properties.CustomProperties.Longitude = str2double(deployinfo{5});

X.Properties.CustomProperties

%% Save matlab file
% Prompt for user savefile if no arguments to routine (interactive mode)
if nargin < 2
    filename = strcat(name,'.mat')
    savefile = uiputfile(filename, ...
        'LOADCSV: Select a file to save MAT-file data to');
    if ischar(savefile) % Only if a savefile is selected
        save(savefile,'X');
    end
end
% Save data structure to a file if SAVEFILE argument is used
if nargin ==2
    if savefile > 0
     save(savefile,'X');
    end
end




