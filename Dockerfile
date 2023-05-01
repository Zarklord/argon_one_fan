FROM alpine:latest

MAINTAINER Zarklord

RUN apk add i2c-tools mosquitto-clients --no-cache;

COPY --chmod=0755 run.sh /

ENV TEMP_MODE=C \
    MIN_TEMP=55 \
    MAX_TEMP=65 \
    LOG_TEMP=0 \
    MQTT_HOST= \
    MQTT_PORT=1883 \
    MQTT_USERNAME= \
    MQTT_PASSWORD= \
    MQTT_TOPIC=

ENTRYPOINT /run.sh
