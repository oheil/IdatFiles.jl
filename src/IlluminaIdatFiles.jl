
module IlluminaIdatFiles

using Base64,LightXML

include("decrypt_des.jl")

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

mutable struct Idat
	nSNPsRead::Int32

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


	function Idat(nSNPsRead=0)
		new(
			nSNPsRead,
			Dict{String,AbstractArray}(),
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
			"",
			"",
			"",
			"",
			"",
		)
	end
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

function idat_read(file::AbstractString)
	io=open(file,"r")
	idat=idat_read(io)
	close(io)
	idat
end

function idat_read(io::IO)::Idat
	seekstart(io)
	#b=Array{UInt8,1}(undef,4)
	b=zeros(UInt8,4)
	readbytes!(io, b,length(b))
	magic=join(Array{Char}(b))
	
	if magic != "IDAT"
		@warn "magic bytes don't match 'IDAT'"
	end

	version=read(io,Int32)
	if version == 3
		skip(io,4)
		return idat_read_v3(io::IO)
	end
	if version == 1
		skip(io,1)
		return idat_read_v1(io::IO)
	end
	
	@warn "version "*string(version)*" is unknown"
	return Idat()
end

function idat_read_v1(io::IO)
	#idatKey=Array{Int8}([127, 10, 73, -115, -47, -40, 25, -85])
	idatKey=Array{UInt8,1}([0x7f, 0x0a, 0x49, 0x8d, 0xd1, 0xd8, 0x19, 0xab])

	#sessionKey=Array{UInt8,1}(undef,8)
	sessionKey=zeros(UInt8,8)
	readbytes!(io, sessionKey,length(sessionKey))

	buffer=zeros(UInt32,8)

	context1=IlluminaIdatFiles.Gl_des_ctx()
	IlluminaIdatFiles.gl_des_setkey!(context1,idatKey,buffer)
	decrypted_sessionKey=zeros(UInt8,8)
	IlluminaIdatFiles.gl_des_ecb_decrypt!(context1,sessionKey,decrypted_sessionKey,buffer)

	context2=IlluminaIdatFiles.Gl_des_ctx()
	IlluminaIdatFiles.gl_des_setkey!(context2,decrypted_sessionKey,buffer)

	data=read(io)
	startindex=firstindex(data)
	endindex=startindex+8-1
	while(endindex<=length(data))
		v=view(data,startindex:endindex)
		IlluminaIdatFiles.gl_des_ecb_decrypt!(context2,v,v,buffer)
		startindex+=8
		endindex=startindex+8-1
	end
	if startindex <= length(data)
		endindex=length(data)
		v=zeros(UInt8,8)
		v[1:(endindex-startindex+1)].=data[startindex:endindex]
		IlluminaIdatFiles.gl_des_ecb_decrypt!(context2,v,v,buffer)
		data[startindex:endindex].=v[1:(endindex-startindex+1)]
	end
	xdoc=parse_string(String(Char.(data[5:end])));
	rel=root(xdoc);
	attrDict=attributes_dict(rel);
	idat=Idat()
	dataBinTypes=Dict(
		"__MeanBinData" => Float32,
		"__TrimmedMeanBinData" => Float32,
		"__DevBinData" => Float32,
		"__MedianBinData" => Float32,
		"__BackgroundBinData" => Float32,
		"__BackgroundDevBinData" => Float32,
		"__IllumicodeBinData" => UInt32,
		"__CodesBinData" => UInt32,
		"__NumBeadsBinData" => UInt32,
		"__NumGoodBeadsBinData" => UInt32,
		"Opa" => nothing,
		"DnaPlate" => nothing,
		"Well" => nothing,
		"Dna" => nothing,
	)
	dataTypes=Dict(
		"__MeanBinData" => Float64,
		"__TrimmedMeanBinData" => Float64,
		"__DevBinData" => Float64,
		"__MedianBinData" => Float64,
		"__BackgroundBinData" => Float64,
		"__BackgroundDevBinData" => Float64,
		"__IllumicodeBinData" => Int,
		"__CodesBinData" => Int,
		"__NumBeadsBinData" => Int,
		"__NumGoodBeadsBinData" => Int,
		"Opa" => nothing,
		"DnaPlate" => nothing,
		"Well" => nothing,
		"Dna" => nothing,
	)
	for attr in keys(attrDict)
		if haskey(dataBinTypes,attr)
			if dataBinTypes[attr] !== nothing
				data=base64decode(attrDict[attr])
				tmpdata=zeros(dataBinTypes[attr], div(sizeof(data),4) )
				read!(IOBuffer(data),tmpdata)
				idat.data[attr] = (dataTypes[attr]).(tmpdata)
			end
		else
			@warn "Unknown attribute "*attr
		end
	end
	for el in child_elements(rel)
		if name(el)=="TenthPercentile"
			idat.tenthPercentile = parse(Int,content(el))
		elseif name(el)=="SampleBeadSet"
			idat.sampleBeadSet = content(el)
		elseif name(el)=="BarCode"
			idat.barcode = content(el)
		elseif name(el)=="SentrixFormat"
			idat.sentrixFormat = content(el)
		elseif name(el)=="SectionLabel"
			idat.sectionLabel = content(el)
		elseif name(el)=="BeadSet"
			idat.beadSet = content(el)
		elseif name(el)=="VeracodeLotNumber"
			idat.veracodeLotNumber = content(el)
		elseif name(el)=="ProcessHistory"
			phname=Array{String,1}(undef,0)
			softwareApp=Array{String,1}(undef,0)
			version=Array{String,1}(undef,0)
			date=Array{String,1}(undef,0)
			parameters=Array{String,1}(undef,0)
			for processEntryEl in child_elements(el)
				for detailEl in child_elements(processEntryEl)
					if name(detailEl)=="Name"
						push!(phname,content(detailEl))
					elseif name(detailEl)=="SoftwareApp"
						push!(softwareApp,content(detailEl))
					elseif name(detailEl)=="Version"
						push!(version,content(detailEl))
					elseif name(detailEl)=="Date"
						push!(date,content(detailEl))
					elseif name(detailEl)=="Parameters"
						push!(parameters,content(detailEl))
					else
						@warn "Unknown ProcessHistory subelement "*name(detailEl)
					end
				end
			end
			idat.data["Name"]=phname
			idat.data["SoftwareApp"]=softwareApp
			idat.data["Version"]=version
			idat.data["Date"]=date
			idat.data["Parameters"]=parameters
		else
			@warn "Unknown child element "*name(el)
		end
	end
	free(xdoc)
	idat
end

function idat_read_v3(io::IO)
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
	dataBinTypes=Dict(
		"IlluminaID" => Int32,
		"SD" => UInt16,
		"Mean" => UInt16,
		"NBeads" => UInt8,
		"MidBlock" => Int32,
		"RunInfo" => Int32,
		"blockType" => String,
		"blockPars" => String,
		"blockCode" => String,
		"codeVersion" => String,
	)
	dataTypes=Dict(
		"IlluminaID" => Int,
		"SD" => Int,
		"Mean" => Int,
		"NBeads" => Int,
		"MidBlock" => Int,
		"RunInfo" => Int,
		"blockType" => String,
		"blockPars" => String,
		"blockCode" => String,
		"codeVersion" => String,
	)

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
			codes[index]="newField"*string(nNewField)
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

	idat=Idat(nSNPsRead)

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
			if findfirst( isequal(codes[index]), collect(keys(dataTypes)) ) !== nothing
				n=nSNPsRead
				if codes[index]=="MidBlock"
					n=read(io,Int32)
					nextPosition+=sizeof(Int32)
				end
				if codes[index]=="RunInfo"
					n=read(io,Int32)
					nextPosition+=sizeof(Int32)
					for runInfo in ["runTime","blockType","blockPars","blockCode","codeVersion"]
						idat.data[runInfo]=Array{String,1}(undef,n)
					end
					for i in 1:n
						for runInfo in ["runTime","blockType","blockPars","blockCode","codeVersion"]
							(idat.data[runInfo][i],nbytes)=read_string(io)
							nextPosition+=nbytes
						end
					end
				else
					tmpdata=zeros(dataBinTypes[codes[index]],n)
					read!(io, tmpdata)
					nextPosition+=n*sizeof(eltype(tmpdata))
					idat.data[codes[index]] = (dataTypes[codes[index]]).(tmpdata)
				end
			elseif codes[index]=="RedGreen"
				idat.redGreen=read(io,typeof(idat.redGreen))
				nextPosition+=sizeof(typeof(idat.redGreen))
			elseif codes[index]=="MostlyNull"
				(idat.mostlyNull,nbytes)=read_string(io)
				nextPosition+=nbytes
			elseif codes[index]=="Barcode"
				(idat.barcode,nbytes)=read_string(io)
				nextPosition+=nbytes
			elseif codes[index]=="ChipType"
				(idat.chipType,nbytes)=read_string(io)
				nextPosition+=nbytes
			elseif codes[index]=="MostlyA"
				(idat.mostlyA,nbytes)=read_string(io)
				nextPosition+=nbytes
			elseif codes[index]=="Unknown1"
				(idat.unknown1,nbytes)=read_string(io)
				nextPosition+=nbytes
			elseif codes[index]=="Unknown2"
				(idat.unknown2,nbytes)=read_string(io)
				nextPosition+=nbytes
			elseif codes[index]=="Unknown3"
				(idat.unknown3,nbytes)=read_string(io)
				nextPosition+=nbytes
			elseif codes[index]=="Unknown4"
				(idat.unknown4,nbytes)=read_string(io)
				nextPosition+=nbytes
			elseif codes[index]=="Unknown5"
				(idat.unknown5,nbytes)=read_string(io)
				nextPosition+=nbytes
			elseif codes[index]=="Unknown6"
				(idat.unknown6,nbytes)=read_string(io)
				nextPosition+=nbytes
			elseif codes[index]=="Unknown7"
				(idat.unknown7,nbytes)=read_string(io)
				nextPosition+=nbytes
			else
				@warn "Unknown code: "*codes[index]
			end
		end
	end
	idat
end

end #module IlluminaIdatFiles

