CXX = g++
CXXFLAGS = -g -Wall -O4 -mavx -lcrypto

PROGRAMS = problems solvement generator
BLOCKS   = twofish.o common.o chain.o sha384.o flag_coder.o sha256.o

all : $(PROGRAMS)

problems: problem.o $(BLOCKS)
	$(CXX) $(CXXFLAGS) -o $@ $^
	
solvement: solver.o $(BLOCKS)
	$(CXX) $(CXXFLAGS) -o $@ $^

generator: generator.o $(BLOCKS)
	$(CXX) $(CXXFLAGS) -o $@ $^
	
%.o: %.cpp 
	$(CXX) $(CXXFLAGS) -o $@ -c $^

clean:
	$(RM) $(PROGRAMS)
	$(RM) *.o *.~
