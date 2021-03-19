# IlluminaIdatFiles

This is a low level IO package for Illumina .idat files

**References**

The implementation follows the code of the [R bioconductor package illuminaio](http://www.bioconductor.org/packages/release/bioc/html/illuminaio.html) by 
* Smith, L M, Baggerly, A K, Bengtsson, Henrik, Ritchie, E M, Hansen, D K (2013). “illuminaio: An open source IDAT parsing tool for Illumina microarrays.” F1000Research, 2(264). [doi: 10.12688/f1000research.2-264.v1](https://f1000research.com/articles/2-264). 

## Currently supported files

This package is in an early stage and the following microarrays .idat files are supported:
* Illumina HumanRef-8 Expression BeadChips
* Illumina HumanHT 12 Gene Expression BeadChip
* Illumina Infinium MethylationEPIC BeadChip
* Illumina Infinium Human Methylation 450K BeadChip
* Illumina Infinium Mouse Methylation BeadChip

e.g. 204792200130_R01C01_Grn.idat, 204792200130_R01C01_Red.idat

## Dependencies

#### Julia versions

* Julia 1.0 or above

#### Third party packages

* LightXML 0.9 (or above but upper bound is mandatory)

#### Standard Library packages

* Base64

## Usage

#### General usage
```julia
using Pkg
Pkg.add("IlluminaIdatFiles");
#Pkg.add(url="https://github.com/oheil/IlluminaIdatFiles.jl",rev="master")

using IlluminaIdatFiles
```
To read an illumina idat file use the following command:
```julia
idat = idat_read(filename)
```
Examples:
```julia
filename = raw"c:\temp\idat\204792200130_R01C01_Grn.idat"
idat = idat_read(filename)
```

```julia
using GZip
fh = GZip.open("204792200130_R01C01_Red.idat.gz")
idat = idat_read(fh)
close(fh)
```

```julia
using GZip
idat = GZip.open("204792200130_R01C01_Red.idat.gz") |> idat_read
```

```julia
using TranscodingStreams, CodecZlib
stream = GzipDecompressorStream(open("204792200130_R01C01_Red.idat.gz"))
idat = idat_read(stream)
close(stream)
```

```julia
using TranscodingStreams, CodecZlib
idat = GzipDecompressorStream(open("204792200130_R01C01_Red.idat.gz")) |> idat_read
```

The returned `idat` is a struct of type `IlluminaIdatFiles.Idat`:
```julia
mutable struct Idat
    nRead::Int32
    data::Dict{String,AbstractArray}
    redGreen::Int32
    mostlyNull::String
    barcode::String
    chipType::String
    mostlyA::String
    unknown1::String
    unknown2::String
    unknown3::String
    unknown4::String
    unknown5::String
    unknown6::String
    unknown7::String
    tenthPercentile::Int
    sampleBeadSet::String
    sentrixFormat::String
    sectionLabel::String
    beadSet::String
    veracodeLotNumber::String
end
```
Where the most important member is
```
idat.data
```
which contains all data (and some other) arrays available in the .idat file:
##### e.g. Illumina Infinium MethylationEPIC BeadChip:
```
julia> idat.data
Dict{String,AbstractArray} with 10 entries:
  "IlluminaID"  => [1600101, 1600111, 1600115, 1600123, 1600131,...
  "Mean"        => [3165, 812, 456, 1848, 101, 7450, 5153, 947, 620, 364, ...
  "SD"          => [229, 288, 233, 219, 60, 983, 683, 169,...
  "NBeads"      => [14, 7, 19, 14, 14, 10, 16, 15, 12, 12...
  ...

julia> keys(idat.data)
Base.KeySet for a Dict{String,AbstractArray} with 10 entries. Keys:
  "blockType"
  "NBeads"
  "MidBlock"
  "codeVersion"
  "SD"
  "runTime"
  "blockPars"
  "IlluminaID"
  "Mean"
  "blockCode"
```
##### e.g. Illumina HumanHT 12 Gene Expression BeadChip:
```
julia> idat.data
Dict{String,AbstractArray} with 15 entries:
  "__IllumicodeBinData"    => [10008, 10010, 10014, 10017, 10019, 10020,...
  "__MeanBinData"          => [768.46, 94.0066, 86.5272, 94.533, 112.999,...
  "__NumBeadsBinData"      => [23, 22, 21, 25, 16, 26, 24, 17,...
  ...

julia> keys(idat.data)
Base.KeySet for a Dict{String,AbstractArray} with 15 entries. Keys:
  "__CodesBinData"
  "SoftwareApp"
  "__BackgroundBinData"
  "Date"
  "__IllumicodeBinData"
  "Version"
  "__TrimmedMeanBinData"
  "Name"
  "__BackgroundDevBinData"
  "__DevBinData"
  "__MeanBinData"
  "Parameters"
  "__NumGoodBeadsBinData"
  "__NumBeadsBinData"
  "__MedianBinData"  
```

The keys are the original data specifiers present in the .idat file, which are different for the different chip types and maybe different between versions.

