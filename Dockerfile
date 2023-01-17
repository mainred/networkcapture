FROM ubuntu:20.04

RUN apt-get update -qq -y && apt-get upgrade -y && \
    apt-get install net-tools libcap2 tcpdump -y && \
    apt-get install util-linux iproute2 -y

COPY ./capture.sh /capture.sh
RUN chmod +x /capture.sh
ENTRYPOINT ["/capture.sh"]
