# $Id$

SOURCES=job.ml runon.ml
STDLIBS=unix.cma str.cma
STDOPTLIBS=unix.cmxa str.cmxa

all: runon

opt: runon.opt

docs: docs/html/index.html

docs/html/index.html: $(SOURCES)
	ocamldoc -html -d docs/html $(SOURCES)

runon: $(SOURCES)
	ocamlc -o runon -pp camlp4o $(CFLAGS) $(STDLIBS) $(SOURCES)

runon.opt: $(SOURCES)
	ocamlopt -o runon.opt -pp camlp4o $(CFLAGS) $(STDOPTLIBS) $(SOURCES)
	strip runon.opt

clean:
	@rm -f runon runon.opt *.o *.cm?
