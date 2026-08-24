# DL4 PrecipMet Parser

`dl4_PrecipMet.pl` converts binary data from DL4-PrecipMet firmware v1.0.0 into minute-resolution CSV data.

## Requirements

- Perl with `Time::Local` and `Getopt::Std` (both core Perl modules).
- An `inst_loc` file in the directory from which the script is run.
- A matching release entry in `inst_loc` for the instrument ID supplied on the command line.

The `inst_loc` fields are whitespace-delimited:

```text
DL4-0109 del_mar_01 rR3 20 39.244842 -123.021849 20171109010600 20300520204700 1 Del_Mar
```

| Field | Name | Description |
| --- | --- | --- |
| 0 | Sensor number | Instrument ID supplied as the first argument to the processing script. |
| 1 | Output filename | Output prefix. The script writes `<output-prefix>m_raw.csv`. |
| 2 | Sensor flags | Precipitation 0, precipitation 1, and battery configuration. Lowercase `r` enables precipitation output; uppercase `R` writes `NaN` for that precipitation field. Existing flag values normally do not need changes. |
| 3 | Sensor elevation | Elevation in meters. |
| 4 | Latitude | Latitude in decimal degrees. |
| 5 | Longitude | Longitude in decimal degrees. |
| 6 | Start time | UTC deployment start time, formatted `YYYYMMDDhhmmss`. Use this to omit data before a chosen time. |
| 7 | End time | UTC recovery end time, formatted `YYYYMMDDhhmmss`. Use this to truncate data after a chosen time. |
| 8 | Site number | Numeric site identifier. |
| 9 | Site name | Site name. Use `_` between words; the script converts underscores to spaces in output. |

Lines beginning with `#` may be used as comments, but the script expects every data line to contain all ten fields.

## Usage

Run the script from the directory containing `inst_loc`:

```bash
perl /path/to/dl4_PrecipMet.pl DL4-0109 DL4-PrecipMet_I0109_SD109_2025-11-03.bin
```

Options:

```text
-d    Print header timestamps while processing.
-q    Print data lines while processing.
```

For example:

```bash
perl /path/to/dl4_PrecipMet.pl -d DL4-0109 DL4-PrecipMet_I0109_SD109_2025-11-03.bin
```

## Output

The script writes the following files to its current directory:

- `status.log`: processing status and firmware information.
- `<output-prefix>m_raw.csv`: minute-resolution precipitation data, when more than one data point is found.

For the example `inst_loc` entry, the CSV is `del_mar_01m_raw.csv`.

## MATLAB Plotting

The MATLAB scripts are in [matlab](matlab). The main plotting entry point is `plotPrecipMet.m`.

Add the `matlab` directory to the MATLAB path, then either run it interactively or pass a CSV filename:

```matlab
addpath('path/to/DL4-PrecipMet/matlab')
plotPrecipMet
plotPrecipMet('del_mar_01m_raw.csv')
```

`plotPrecipMet.m` loads DL4 PrecipMet CSV or MAT data and creates a three-panel figure with cumulative precipitation, per-minute precipitation, and battery voltage. The plot axes share a time range, update the displayed date range after zooming or panning, and provide data-cursor values.

Supporting scripts:

- `loadcsv.m`: reads the parser CSV output into a UTC MATLAB timetable and adds site metadata from the CSV header. It can also save the loaded timetable as a MAT file.
- `customDataTip.m`: formats data-cursor values with timestamp, data index, and y-value.
- `enableDynamicTimeTitle.m`: installs the zoom/pan-aware time-range title on the top plot tile. The file currently defines `enableDynamicTimeTitleTopTile`; rename that function to `enableDynamicTimeTitle` or update the call in `plotPrecipMet.m` before using this helper.

## Binary File Handling

The parser skips consecutive 512-byte blocks containing only `0xFF` bytes at the beginning of a binary file before reading the first record header. It also skips records whose header timestamp is outside the deployment and recovery window in `inst_loc`, then continues scanning later records.

## License

This software is Copyright © 2026 The Regents of the University of California. All Rights Reserved.

## Contact & Support

For issues or questions:
- Check usage section above
- Contact: Douglas Alden