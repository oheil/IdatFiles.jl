
module IlluminaIdatFiles

export idat_read

function read_string(io)
	bytes=0
	m=read(io, UInt8)
	bytes+=sizeof(UInt8)
	n=mod(m,128)
	shift=0
	while div(m,128,RoundDown)==1
		m=read(io, UInt8)
		bytes+=sizeof(UInt8)
		shift=shift+7
		k=<<(mod(m,128),shift)
		n+=k
	end
	b=Array{UInt8,1}(undef,n)
	readbytes!(io,b,n)
	bytes+=n
	(join(Array{Char}(b)),bytes)
end

knownCodes = Dict(
     1000 => "nSNPsRead" ,
      102 => "IlluminaID",
      103 => "SD"        ,
      104 => "Mean"      ,
      107 => "NBeads"    ,
      200 => "MidBlock"  ,
      300 => "RunInfo"   ,
      400 => "RedGreen"  ,
      401 => "MostlyNull", # 'Manifest', cf [1].
      402 => "Barcode"   ,
      403 => "ChipType"  ,
      404 => "MostlyA"   , # 'Stripe', cf [1].
      405 => "Unknown1" ,
      406 => "Unknown2" , # 'Sample ID', cf [1].
      407 => "Unknown3" ,
      408 => "Unknown4" , # 'Plate', cf [1].
      409 => "Unknown5" , # 'Well', cf [1].
      410 => "Unknown6" ,
      510 => "Unknown7" 
    )

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

function idat_seek(io::IO, nextPosition::Int)
	try
		seek(io,nextPosition)
	catch
		#if seek failes, try to read und discard nextPosition bytes
		@warn "seek failed for stream of type "*string(typeof(io))*", trying to read and discard with performance regression"
		seekstart(io)
		read(io, nextPosition)
	end
end

function idat_read(io::IO)
	seekstart(io)
	b=Array{UInt8,1}(undef,4)
	readbytes!(io, b,length(b))
	magic=join(Array{Char}(b))

	version=read(io,Int64)
	nfields=read(io,Int32)

	codes=Array{String,1}(undef,nfields)

	fieldCodes=Array{UInt16,1}(undef,nfields)
	byteOffsets=Array{Int64,1}(undef,nfields)
	nNewField=1
	nSNPsReadIndex=-1
	for index in 1:nfields
		fieldCodes[index]=read(io,UInt16)
		byteOffsets[index]=read(io,Int64)
		if haskey(knownCodes,fieldCodes[index])
			codes[index]=knownCodes[fieldCodes[index]]
		else
			codes[index]="newField"*nNewField
			nNewField+=1
		end
		if knownCodes[fieldCodes[index]]=="nSNPsRead"
			nSNPsReadIndex=index
		end
	end

	nextPosition=byteOffsets[nSNPsReadIndex]
	idat_seek(io,nextPosition)
	nSNPsRead = read(io,Int32)
	nextPosition+=4

	idat=Idat(
		nSNPsRead,
		Array{Int,1}(undef,nSNPsRead),
		Array{Int,1}(undef,nSNPsRead),
		Array{Int,1}(undef,nSNPsRead),
		Array{Int,1}(undef,nSNPsRead),
		-1,
		Array{Int32,1}(undef,0),
		-1,
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		-1,
		Array{String,1}(undef,0),
		Array{String,1}(undef,0),
		Array{String,1}(undef,0),
		Array{String,1}(undef,0),
		Array{String,1}(undef,0)
	)

	sortedOffsets=sortperm(byteOffsets)
	for index in sortedOffsets
		if index != nSNPsReadIndex
			code=codes[index]
			offset=byteOffsets[index]
			step=offset-nextPosition
			if step>0
				skip(io,step)
				nextPosition+=step
			end
			if step<0
				idat_seek(io,offset)
				nextPosition=offset
			end
			if codes[index]=="IlluminaID"
				illuminaID=Array{Int32,1}(undef,nSNPsRead)
				read!(io, illuminaID)
				nextPosition+=nSNPsRead*sizeof(eltype(illuminaID))
				idat.illuminaID=Int.(illuminaID)
			elseif codes[index]=="SD"
				sd=Array{UInt16,1}(undef,nSNPsRead)
				read!(io, sd)
				nextPosition+=nSNPsRead*sizeof(eltype(sd))
				idat.sd=Int.(sd)
			elseif codes[index]=="Mean"
				mean=Array{UInt16,1}(undef,nSNPsRead)
				read!(io, mean)
				nextPosition+=nSNPsRead*sizeof(eltype(mean))
				idat.mean=Int.(mean)
			elseif codes[index]=="NBeads"
				nbeads=Array{UInt8,1}(undef,nSNPsRead)
				read!(io, nbeads)
				nextPosition+=nSNPsRead*sizeof(eltype(nbeads))
				idat.nbeads=Int.(nbeads)
			elseif codes[index]=="MidBlock"
				idat.nMidBlockEntries=read(io,typeof(idat.nMidBlockEntries))
				nextPosition+=sizeof(typeof(idat.nMidBlockEntries))
				idat.midBlock=Array{Int32,1}(undef,idat.nMidBlockEntries)
				read!(io, idat.midBlock)
				nextPosition+=idat.nMidBlockEntries*sizeof(eltype(idat.midBlock))
			elseif codes[index]=="RunInfo"
				idat.nRunInfoBlocks=read(io,typeof(idat.nRunInfoBlocks))
				nextPosition+=sizeof(typeof(idat.nRunInfoBlocks))
				idat.runTime=Array{String,1}(undef,idat.nRunInfoBlocks)
				idat.blockType=Array{String,1}(undef,idat.nRunInfoBlocks)
				idat.blockPars=Array{String,1}(undef,idat.nRunInfoBlocks)
				idat.blockCode=Array{String,1}(undef,idat.nRunInfoBlocks)
				idat.codeVersion=Array{String,1}(undef,idat.nRunInfoBlocks)
				for i in 1:idat.nRunInfoBlocks
					(idat.runTime[i],n)=read_string(io)
					nextPosition+=n
					(idat.blockType[i],n)=read_string(io)
					nextPosition+=n
					(idat.blockPars[i],n)=read_string(io)
					nextPosition+=n
					(idat.blockCode[i],n)=read_string(io)
					nextPosition+=n
					(idat.codeVersion[i],n)=read_string(io)
					nextPosition+=n
				end
			elseif codes[index]=="RedGreen"
				idat.redGreen=read(io,typeof(idat.redGreen))
				nextPosition+=sizeof(typeof(idat.redGreen))
			elseif codes[index]=="MostlyNull"
				(idat.mostlyNull,n)=read_string(io)
				nextPosition+=n
			elseif codes[index]=="Barcode"
				(idat.barcode,n)=read_string(io)
				nextPosition+=n
			elseif codes[index]=="ChipType"
				(idat.chipType,n)=read_string(io)
				nextPosition+=n
			elseif codes[index]=="MostlyA"
				(idat.mostlyA,n)=read_string(io)
				nextPosition+=n
			elseif codes[index]=="Unknown1"
				(idat.unknown1,n)=read_string(io)
				nextPosition+=n
			elseif codes[index]=="Unknown2"
				(idat.unknown2,n)=read_string(io)
				nextPosition+=n
			elseif codes[index]=="Unknown3"
				(idat.unknown3,n)=read_string(io)
				nextPosition+=n
			elseif codes[index]=="Unknown4"
				(idat.unknown4,n)=read_string(io)
				nextPosition+=n
			elseif codes[index]=="Unknown5"
				(idat.unknown5,n)=read_string(io)
				nextPosition+=n
			elseif codes[index]=="Unknown6"
				(idat.unknown6,n)=read_string(io)
				nextPosition+=n
			elseif codes[index]=="Unknown7"
				(idat.unknown7,n)=read_string(io)
				nextPosition+=n
			else
				@warn "Unknown code in file "*file*": "*codes[index]
			end
		end
	end
	idat
end

function idat_read(file::AbstractString)
	io=open(file,"r")
	idat=idat_read(io)
	close(io)
	idat
end

end #module IlluminaIdatFiles

