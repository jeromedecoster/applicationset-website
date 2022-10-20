#!/bin/bash

log()   { echo -e "\e[30;47m ${1} \e[0m ${@:2}"; }        # $1 background white
info()  { echo -e "\e[48;5;28m ${1} \e[0m ${@:2}"; }      # $1 background green
warn()  { echo -e "\e[48;5;202m ${1} \e[0m ${@:2}" >&2; } # $1 background orange
error() { echo -e "\e[48;5;196m ${1} \e[0m ${@:2}" >&2; } # $1 background red

# the directory containing the script file
export PROJECT_DIR="$(cd "$(dirname "$0")"; pwd)"

#
# variables
#
[[ -f $PROJECT_DIR/.env ]] \
    && source $PROJECT_DIR/.env \
    || warn WARN .env file is missing

#
# overwrite TF variables
#
export TF_VAR_project_name=$PROJECT_NAME
export TF_VAR_service_name=$SERVICE_NAME
export TF_VAR_region=$AWS_REGION

# log $1 in underline then $@ then a newline
under() {
    local arg=$1
    shift
    echo -e "\033[0;4m${arg}\033[0m ${@}"
    echo
}

usage() {
    under usage 'call the Makefile directly: make dev
      or invoke this file directly: ./make.sh dev'
}

env-create() {
    local PROJECT_NAME=applicationset

    # setup .env file with default values
    scripts/env-file.sh .env \
        AWS_PROFILE=default \
        PROJECT_NAME=$PROJECT_NAME \
        SERVICE_NAME=as-website \
        APP_NAME=website \
        STORAGE_PORT=5000 \
        CONVERT_PORT=4000 \
        WEBSITE_PORT=3000

    # setup .env file again
    # /!\ use your own values
    scripts/env-file.sh .env \
        AWS_REGION=eu-west-3
}

terraform-init() {
    export CHDIR="$PROJECT_DIR/terraform"
    scripts/terraform-init.sh
    scripts/terraform-validate.sh
}

# terraform create ecr repo + setup .env file
terraform-create() {
    export CHDIR="$PROJECT_DIR/terraform"
    scripts/terraform-validate.sh
    scripts/terraform-apply.sh
}

# run website server using npm - dev mode
website() {
    log WEBSITE_PORT $WEBSITE_PORT
    log STORAGE_PORT $STORAGE_PORT
    log CONVERT_PORT $CONVERT_PORT

    # -f, --fail : Fail silently (no output at all) on server errors.
    # -I, --head : Fetch the headers only.
    # -L, --location : If  the server reports that the requested page has moved 
    #                  to a different location (header and a 3XX response code), this
    #                  option  will make  curl  redo the request on the new place.
    # -o, --output <file> : Write output to <file> instead of stdout.
    # -s, --silent : Don't show progress meter or error messages.
    # -w, --write-out <format> : The format  is a string that may contain plain
    #                            text mixed with any number of variables.
    #              - http_code : The numerical response code that was found in the 
    #                            last retrieved HTTP(S) or FTP(s) transfer.
    [[ $(curl -sfLI localhost:$STORAGE_PORT -o /dev/null -w '%{http_code}') != '200' ]] \
        && { error ABORT localhost:$STORAGE_PORT is not working. Status Code 200 required.; exit 0; } \
        || true

    [[ $(curl -sfLI localhost:$CONVERT_PORT -o /dev/null -w '%{http_code}') != '200' ]] \
        && { error ABORT localhost:$CONVERT_PORT is not working. Status Code 200 required.; exit 0; } \
        || true

    cd "$PROJECT_DIR/$APP_NAME"
    npm install
    NODE_ENV=development \
        WEBSITE_PORT=$WEBSITE_PORT \
        CONVERT_HOST=localhost \
        CONVERT_PORT=$CONVERT_PORT \
        STORAGE_HOST=localhost \
        STORAGE_PORT=$STORAGE_PORT \
        DEBUG=$APP_NAME npx nodemon index.js
}

dev-build() {
    cd "$PROJECT_DIR/$APP_NAME"
    docker image build \
        --file Dockerfile.dev \
        --tag $APP_NAME-dev \
        .

    docker images \
        --filter="reference=$APP_NAME-dev" \
        --filter="reference=$APP_NAME" \
        --filter="reference=$REPOSITORY_URL"
}

dev-run() {
    # see `website` function
    [[ $(curl -sfLI localhost:$STORAGE_PORT -o /dev/null -w '%{http_code}') != '200' ]] \
        && { error ABORT localhost:$STORAGE_PORT is not working. Status Code 200 required.; exit 0; } \
        || true

    [[ $(curl -sfLI localhost:$CONVERT_PORT -o /dev/null -w '%{http_code}') != '200' ]] \
        && { error ABORT localhost:$CONVERT_PORT is not working. Status Code 200 required.; exit 0; } \
        || true

    # Warn: --network host is required to connect to other services running on localhost
    # https://docs.docker.com/network/network-tutorial-host/
    docker run \
        --rm \
        --env-file .env \
        --env NODE_ENV=development \
        --env CONVERT_HOST=localhost \
        --env STORAGE_HOST=localhost \
        --network host \
        --name $APP_NAME-dev \
        $APP_NAME-dev
}

dev-stop() {
    docker rm --force $APP_NAME-dev 2>/dev/null
}

# run the project using docker-compose (same as storage + convert + website commands)
up() {
    export COMPOSE_PROJECT_NAME=applicationset
    docker-compose \
        --env-file .env \
        --file docker-compose.dev.yml \
        up \
        --remove-orphans \
        --force-recreate \
        --build \
        --no-deps 
}

# stop docker-compose + remove volumes
down() {
  export COMPOSE_PROJECT_NAME=applicationset
  docker-compose \
    --file docker-compose.dev.yml \
    down \
    --volumes
}

prod-build() {
    cd "$PROJECT_DIR/$APP_NAME"
    docker image build \
        --tag $APP_NAME \
        .

    docker images \
        --filter="reference=$APP_NAME-dev" \
        --filter="reference=$APP_NAME" \
        --filter="reference=$REPOSITORY_URL"
}

prod-run() {
    # see `website` function
    [[ $(curl -sfLI localhost:$STORAGE_PORT -o /dev/null -w '%{http_code}') != '200' ]] \
        && { error ABORT localhost:$STORAGE_PORT is not working. Status Code 200 required.; exit 0; } \
        || true

    [[ $(curl -sfLI localhost:$CONVERT_PORT -o /dev/null -w '%{http_code}') != '200' ]] \
        && { error ABORT localhost:$CONVERT_PORT is not working. Status Code 200 required.; exit 0; } \
        || true

    docker run \
        --rm \
        --env-file .env \
        --env CONVERT_HOST=localhost \
        --env STORAGE_HOST=localhost \
        --network host \
        --name $APP_NAME \
        $APP_NAME
}

prod-stop() {
    docker rm --force $APP_NAME 2>/dev/null
}

update-patch() {
    log APP_NAME $APP_NAME

    VERSION=$(jq --raw-output '.version' $APP_NAME/package.json)
    log VERSION $VERSION

    UPDATED=$(semver-cli inc patch $VERSION)
    log UPDATED $UPDATED

    # https://stackoverflow.com/a/68136589
    # output redirection produces empty file with jq
    # needed to store in $UPDATED variable before write
    PACKAGE=$(jq ".version = \"$UPDATED\"" $APP_NAME/package.json)
    echo "$PACKAGE" > $APP_NAME/package.json

    info UPDATE $APP_NAME/package.json version to $(jq .version --raw-output $APP_NAME/package.json)
}

# push website image to ecr
ecr-push() {
    info MAKE prod-build
    prod-build

    cd "$PROJECT_DIR"
    log APP_NAME $APP_NAME
    log AWS_ACCOUNT_ID $AWS_ACCOUNT_ID
    log AWS_REGION $AWS_REGION
    log REPOSITORY_URL $REPOSITORY_URL

    # add login data into /home/$USER/.docker/config.json (create or update authorization token)
    aws ecr get-login-password \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        | docker login \
        --username AWS \
        --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

    # https://git-scm.com/docs/git-rev-parse#Documentation/git-rev-parse.txt---shortlength
    # default length is 7
    SHORT_SHA=$(git rev-parse --short=9 HEAD)
    log SHORT_SHA $SHORT_SHA

    VERSION=$(jq --raw-output '.version' $APP_NAME/package.json)
    log VERSION $VERSION

    # https://docs.docker.com/engine/reference/commandline/tag/
    docker tag $APP_NAME $REPOSITORY_URL:$SHORT_SHA
    docker tag $APP_NAME $REPOSITORY_URL:$VERSION
    docker tag $APP_NAME $REPOSITORY_URL:latest
    # https://docs.docker.com/engine/reference/commandline/push/
    docker push $REPOSITORY_URL:$SHORT_SHA
    docker push $REPOSITORY_URL:$VERSION
    docker push $REPOSITORY_URL:latest
}

increase-build-push() {
    info MAKE update-patch
    update-patch

    info MAKE ecr-push
    ecr-push
}

up-aws() {
    export COMPOSE_PROJECT_NAME=applicationset
    docker-compose \
        --env-file .env \
        --file docker-compose.aws.yml \
        up \
        --remove-orphans \
        --force-recreate \
        --build \
        --no-deps 
}

# stop docker-compose + remove volumes
down-aws() {
  export COMPOSE_PROJECT_NAME=applicationset
  docker-compose \
    --file docker-compose.aws.yml \
    down \
    --volumes
}

# terraform destroy ecr repo
terraform-destroy() {
    terraform -chdir=$PROJECT_DIR/terraform destroy -auto-approve
}

# clear docker images
clear() {
    log REPOSITORY_URL $REPOSITORY_URL
    # https://stackoverflow.com/a/58821333/1503073
    # remove all tags from an image

    # https://stackoverflow.com/a/8296746/1503073
    # ignore xargs commands if stdin input is empty
    # if `docker images --filter` return nothing, `xargs docker rmi`` throw 
    # an error : "docker rmi" requires at least 1 argument.

    # xargs option
    # -r, --no-run-if-empty : if the standard input does not contain any nonblanks, do not run the command.
    docker images --filter="reference=$APP_NAME" --format='{{.ID}}' \
        | xargs --no-run-if-empty docker rmi --force
    docker images --filter="reference=$APP_NAME-dev" --format='{{.ID}}' \
        | xargs --no-run-if-empty docker rmi --force
    docker images --filter="reference=$REPOSITORY_URL" --format='{{.ID}}' \
        | xargs --no-run-if-empty docker rmi --force

    # https://docs.docker.com/engine/reference/commandline/image_prune/
    # remove unused images
    docker image prune --force
}

# if `$1` is a function, execute it. Otherwise, print usage
# compgen -A 'function' list all declared functions
# https://stackoverflow.com/a/2627461
FUNC=$(compgen -A 'function' | grep $1)
[[ -n $FUNC ]] && { info EXECUTE $1; eval $1; } || usage;
exit 0
