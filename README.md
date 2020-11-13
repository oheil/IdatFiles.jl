# IdatFiles

This is a low level IO package for Illumina .idat files

**References**

The implementation follows the code of the [R bioconductor package illuminaio](http://www.bioconductor.org/packages/release/bioc/html/illuminaio.html) by 
* Smith, L M, Baggerly, A K, Bengtsson, Henrik, Ritchie, E M, Hansen, D K (2013). “illuminaio: An open source IDAT parsing tool for Illumina microarrays.” F1000Research, 2(264). [doi: 10.12688/f1000research.2-264.v1](https://f1000research.com/articles/2-264). 

## Currently supported files

This is an early stage and only the following files are supported:
* Illumina Human Methylation Epic
  e.g. 204792200130_R01C01_Grn.idat, 204792200130_R01C01_Red.idat

## Dependencies

#### Julia versions

* Julia 1.0 or above

#### Third party packages

* none

#### Standard Library packages

* none

## Usage examples

#### General usage
```julia
Pkg.add("IdatFiles");
using IdatFiles;
```
To read an illumina idat file use the following command:
```julia
idat=idat_read(filename)
```




