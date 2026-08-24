# DL4 PrecipMet Parser

`dl4_PrecipMet_20260824.pl` converts binary data from DL4-PrecipMet firmware v1.0.0 into minute-resolution CSV data.

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
perl /path/to/dl4_PrecipMet_20260824.pl DL4-0109 DL4-PrecipMet_I0109_SD109_2025-11-03.bin
```

Options:

```text
-d    Print header timestamps while processing.
-q    Print data lines while processing.
```

For example:

```bash
perl /path/to/dl4_PrecipMet_20260824.pl -d DL4-0109 DL4-PrecipMet_I0109_SD109_2025-11-03.bin
```

## Output

The script writes the following files to its current directory:

- `status.log`: processing status and firmware information.
- `<output-prefix>m_raw.csv`: minute-resolution precipitation data, when more than one data point is found.

For the example `inst_loc` entry, the CSV is `del_mar_01m_raw.csv`.

## Binary File Handling

The parser skips consecutive 512-byte blocks containing only `0xFF` bytes at the beginning of a binary file before reading the first record header. It also skips records whose header timestamp is outside the deployment and recovery window in `inst_loc`, then continues scanning later records.
