FROM registry.k8s.io/build-image/debian-base:bullseye-v1.4.2

RUN apt update && apt upgrade -y && apt install tcpdump -y && apt install util-linux -y

COPY ./capture.sh /capture.sh

ENTRYPOINT ["/capture.sh"]
