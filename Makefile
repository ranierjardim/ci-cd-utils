CLIENT_CREDENTIALS_BASE64:=$(shell base64 -i client-config.yaml)
SERVER_CREDENTIALS_BASE64:=$(shell base64 -i server-config.yaml)
SERVER_ADDRESS=http://localhost:8500
# SERVER_ADDRESS=null # Uncomment this line to use your production server based on client-config.yaml

cmd_run_get_google_oauth2_token:
	dart run src/ci-cd-cmd-utils/bin/ci_cd_cmd_utils.dart google-oauth2-token -a $(SERVER_ADDRESS) --base64 $(CLIENT_CREDENTIALS_BASE64)

cmd_run_get_version_build_number:
	dart run src/ci-cd-cmd-utils/bin/ci_cd_cmd_utils.dart version-build-number -v 1.1.20 -a $(SERVER_ADDRESS) --base64 $(CLIENT_CREDENTIALS_BASE64)

cmd_run_get_version_list:
	dart run src/ci-cd-cmd-utils/bin/ci_cd_cmd_utils.dart version-list -a $(SERVER_ADDRESS) --base64 $(CLIENT_CREDENTIALS_BASE64)

cmd_run_create_keys:
	dart run src/ci-cd-cmd-utils/bin/ci_cd_cmd_utils.dart create-keys

cmd_build_exe:
	dart compile exe src/ci-cd-cmd-utils/bin/ci_cd_cmd_utils.dart -o ci_cd_cmd_utils





server_run:
	dart run src/ci_cd_utils_server/lib/main.dart serve --base64 $(SERVER_CREDENTIALS_BASE64)

server_container_run:
	docker run -it --rm -p 8500:8500 --env TZ=America/Sao_Paulo --env CI_CD_UTILS_SERVER_CREDENTIALS_BASE64=$(SERVER_CREDENTIALS_BASE64) --name ci_cd_utils ranierjardim/ci_cd_utils:local_build

server_container_stop:
	docker stop ci_cd_utils

server_container_build:
	cd src/ci_cd_utils_server/ && docker build -f Dockerfile -t ranierjardim/ci_cd_utils:local_build .

server_container_build_multi_platform:
	cd src/ci_cd_utils_server/ && docker buildx build --push --platform=linux/amd64,linux/arm64,linux/arm/v7 -f Dockerfile -t ranierjardim/ci_cd_utils:$(VERSION) -t ranierjardim/ci_cd_utils:latest .

server_container_kill:
	docker kill ci_cd_utils

server_container_publish:
	docker tag ranierjardim/ci_cd_utils:local_build ranierjardim/ci_cd_utils:$(VERSION)
	docker push ranierjardim/ci_cd_utils:$(VERSION)
