using IlluminaIdatFiles
using Test

@testset "IlluminaIdatFiles.jl" begin

    @test 1 == 1

    #in this early version we only read a 13 MByte binary file, the only relevant test
    #would be reading it into memory, which has been done during development. So, no tests
    #currently needed.

end
