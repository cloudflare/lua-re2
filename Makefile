.PHONY = all clean createdir test

RE2_INC_DIR = /home/syang/develop/regexp/RE2/install/usr/local/include
RE2_LIB_DIR = /home/syang/develop/regexp/RE2/install/usr/local/lib

CXXFLAGS = -fvisibility=hidden -I$(RE2_INC_DIR)  -Wall -MMD -O0 -g
AR_CXXFLAGS = -DBUILDING_LIB
SO_CXXFLAGS = -DBUILDING_LIB -fPIC

CXX_SRC = re2_c.cxx
CXX_OBJ = ${CXX_SRC:.cxx=.o}
AR_OBJ = $(addprefix obj/lib/, $(CXX_OBJ))
SO_OBJ = $(addprefix obj/so/, $(CXX_OBJ))

AR_NAME = libre2c.a
SO_NAME = libre2c.so

BUILD_AR_DIR = obj/lib
BUILD_SO_DIR = obj/so

AR ?= ar
CXX ?= g++

all : $(BUILD_AR_DIR) $(BUILD_SO_DIR) $(AR_NAME) $(SO_NAME) $(RE2C_EX)

$(BUILD_AR_DIR):; mkdir -p $@
$(BUILD_SO_DIR):; mkdir -p $@

createdir :
	@if [ ! -d obj/lib ] ; then mkdir -p obj/lib ; fi && \
	if [ ! -d obj/so ] ; then mkdir -p obj/so ; fi

-include ar_dep.txt
-include so_dep.txt

$(AR_NAME) : $(AR_OBJ)
	$(AR) cru $@ $(AR_OBJ)

$(SO_NAME) : $(SO_OBJ)
	$(CXX) $(CXXFLAGS) $(SO_CXXFLAGS) $(SO_OBJ) -shared -L$(RE2_LIB_DIR) -lre2 -lpthread -o $@
	cat $(BUILD_SO_DIR)/*.d > so_dep.txt

$(AR_OBJ) : $(BUILD_AR_DIR)/%.o : %.cxx
	$(CXX) -c $(CXXFLAGS) $(AR_CXXFLAGS) $< -o $@
	cat $(BUILD_AR_DIR)/*.d > ar_dep.txt

$(SO_OBJ) : $(BUILD_SO_DIR)/%.o : %.cxx
	$(CXX) -c $(CXXFLAGS) $(SO_CXXFLAGS) $< -o $@

clean:
	rm -rf $(PROGRAM) ${BUILD_AR_DIR}/*.[od] ${BUILD_SO_DIR}/*.[od] *.[od] \
        *dep.txt $(AR_NAME) $(SO_NAME) $(RE2C_EX) obj/

test:
	export LD_LIBRARY_PATH=$(LD_LIBRARY_PATH):$(RE2_LIB_DIR):`pwd` ; \
	luajit test.lua
