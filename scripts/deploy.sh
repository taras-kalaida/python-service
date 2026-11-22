#!/usr/bin/env bash

set -Eeuo pipefail

IMAGE_TAG="${IMAGE_TAG:?IMAGE_TAG is required}"
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

rollback() {
    echo "Deployment failed!"

    docker logs "$CONTAINER_NAME" \
        > test-results/container.log 2>&1 || true

    if [ -n "$PREVIOUS_IMAGE" ]; then
        echo "Rolling back to $PREVIOUS_IMAGE"

        export IMAGE_TAG="${PREVIOUS_IMAGE##*:}"

        docker compose -f "$COMPOSE_FILE" \
            up -d --force-recreate --no-build

        for attempt in $(seq 1 20); do
            if curl -fsS --max-time 5 \
                http://localhost:8000/health; then
                echo "Rollback successful"
                return
            fi

            sleep 2
        done

        echo "Rollback health check failed"
    else
        echo "No previous image available for rollback"
    fi
}

trap rollback ERR

echo "Deploying $IMAGE_NAME"

docker image inspect "$IMAGE_NAME" >/dev/null

docker compose -f "$COMPOSE_FILE" \
    up -d --force-recreate --no-build

echo "Waiting for service readiness"

READY=false

for attempt in $(seq 1 20); do
    if curl -fsS --max-time 5 \
        http://localhost:8000/health; then
        READY=true
        break
    fi

    sleep 2
done

if [ "$READY" != "true" ]; then
    echo "Service health check failed"
    false
fi

echo "Running infrastructure tests"

python -m pytest \
    tests/test_infrastructure_linux.py \
    -v \
    --junitxml=test-results/infrastructure.xml

docker logs "$CONTAINER_NAME" \
    > test-results/container.log 2>&1

trap - ERR

echo "Deployment successful: $IMAGE_NAME"