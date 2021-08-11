build:
				dune build --profile release

dev:
				dune exec --profile release -- ./src/pipeline/main.exe -d

dev-unikernel:
				dune exec --profile release -- ./src/pipeline/main.exe -d -u

deploy:
				./deploy.sh

live:
				dune exec --profile release -- ./src/pipeline/main.exe -u --token ./.token