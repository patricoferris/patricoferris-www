build:
				dune build --profile release

dev:
				dune exec --profile release -- ./src/pipeline/main.exe -d

unikernel:
				dune exec --profile release -- ./src/pipeline/main.exe -d -u
