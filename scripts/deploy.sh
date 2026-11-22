#!/usr/bin/env bash

set -Eeuo pipefail

IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG is required}"
HEALTH_FAILURE="${DEPLOY_HEALTH_FAILURE:-false}"

IMAGE_NAME="python-service:${IMAGE_TAG}"
CONTAINER_NAME="python-service"
COMPOSE_FILE="compose.deploy.yaml"

mkdir -p test-results

PREVIOUS_IMAGE=""

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    PREVIOUS_IMAGE=$(docker inspect \
        --format '{{.Config.Image}}' \
        "$CONTAINER_NAME")
fi

check_health() {
    for attempt in $(seq 1 20); do
        if curl --fail --silent --show-error \
            --max-time 5 \
            http://127.0.0.1:8000/health \
            > /dev/null; then
            return 0
        fi

        sleep 2
    done

    return 1
}

rollback() {
    trap - ERR
    set +e

    echo "Deployment failed!"

    docker logs "$CONTAINER_NAME" \
        > test-results/failed-container.log 2>&1

    if [ -z "$PREVIOUS_IMAGE" ]; then
        echo "No previous image available"

        docker compose -f "$COMPOSE_FILE" down \
            > test-results/cleanup.log 2>&1

        exit 1
    fi

    echo "Rolling back to $PREVIOUS_IMAGE"

    if [[ "$PREVIOUS_IMAGE" != python-service:* ]]; then
        echo "Unsupported previous image: $PREVIOUS_IMAGE"
        exit 1
    fi

    export IMAGE_TAG="${PREVIOUS_IMAGE#python-service:}"
    export HEALTH_FAILURE=false

    if ! docker compose -f "$COMPOSE_FILE" \
        up -d --force-recreate --no-build \
        > test-results/rollback.log 2>&1; then

        echo "Rollback failed"
        exit 1
    fi

    if check_health; then
        echo "Rollback successful"
        echo "Restored image: $PREVIOUS_IMAGE"
    else
        echo "Rollback health check failed"
    fi

    docker logs "$CONTAINER_NAME" \
        > test-results/rollback-container.log 2>&1

    exit 1
}

trap rollback ERR

echo "Deploying $IMAGE_NAME"

docker image inspect "$IMAGE_NAME" > /dev/null

export IMAGE_TAG
export HEALTH_FAILURE

docker compose -f "$COMPOSE_FILE" \
    up -d --force-recreate --no-build

echo "Checking service readiness"

if ! check_health; then
    echo "Health check failed"
    false
fi

echo "Running Testinfra"

python -m pytest \
    tests/test_infrastructure_linux.py \
    -v \
    --junitxml=test-results/infrastructure.xml

docker logs "$CONTAINER_NAME" \
    > test-results/container.log 2>&1

trap - ERR

echo "Deployment successful: $IMAGE_NAME"