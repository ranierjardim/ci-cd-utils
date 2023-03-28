run:
	docker run -it --rm -p 4678:4678 --name flutter_remote_control_dedicated_server_container ranierjardim/flutter_remote_control_dedicated_server:local_build

stop:
	docker stop flutter_remote_control_dedicated_server_container

build:
	cd .. && docker build -f ./dedicated-server/Dockerfile -t ranierjardim/flutter_remote_control_dedicated_server:local_build .

kill:
	docker kill flutter_remote_control_dedicated_server_container