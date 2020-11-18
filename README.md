# IlluminaIdatFiles

This is a low level IO package for Illumina .idat files

**References**

The implementation follows the code of the [R bioconductor package illuminaio](http://www.bioconductor.org/packages/release/bioc/html/illuminaio.html) by 
* Smith, L M, Baggerly, A K, Bengtsson, Henrik, Ritchie, E M, Hansen, D K (2013). “illuminaio: An open source IDAT parsing tool for Illumina microarrays.” F1000Research, 2(264). [doi: 10.12688/f1000research.2-264.v1](https://f1000research.com/articles/2-264). 

## Currently supported files

This package is in an early stage and only the following files are supported:
* Illumina Human Methylation Epic


  e.g. 204792200130_R01C01_Grn.idat, 204792200130_R01C01_Red.idat

## Dependencies

#### Julia versions

* Julia 1.0 or above

#### Third party packages

* none

#### Standard Library packages

* none

## Usage

#### General usage
```julia
#Pkg.add("IlluminaIdatFiles");
using Pkg
Pkg.add(url="https://github.com/oheil/IlluminaIdatFiles.jl",rev="master")
using IlluminaIdatFiles;
```
To read an illumina idat file use the following command:
```julia
idat=idat_read(filename)
```
Example:
```julia
filename=raw"c:\temp\idat\204792200130_R01C01_Grn.idat"
data=idat_read(filename)
```
The returned `data` is a struct of type `IlluminaIdatFiles.Idat`:
```julia
mutable struct Idat
    nSNPsRead::Int32
    illuminaID::Array{Int,1}
    sd::Array{Int,1}
    mean::Array{Int,1}
    nbeads::Array{Int,1}
    nMidBlockEntries::Int32
    midBlock::Array{Int32,1}
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
    nRunInfoBlocks::Int32
    runTime::Array{String,1}
    blockType::Array{String,1}
    blockPars::Array{String,1}
    blockCode::Array{String,1}
    codeVersion::Array{String,1}
end
```
Where the most important members are
```
data.illuminaID
data.sd
data.mean
data.nbeads
```

