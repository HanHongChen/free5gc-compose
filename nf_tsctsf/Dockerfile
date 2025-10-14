FROM free5gc/tsctsf-base:latest AS builder
FROM alpine:3.15

LABEL description="tsctsf NF Docker Image" \
    version="1.0"

ENV F5GC_MODULE=tsctsf
ARG DEBUG_TOOLS

RUN if [ "$DEBUG_TOOLS" = "true" ] ; then apk add -U vim strace net-tools iputils-ping curl tcpdump; fi

WORKDIR /free5gc
RUN mkdir -p config/ log/ 

COPY --from=builder /free5gc/${F5GC_MODULE} ./

VOLUME [ "/free5gc/config" ]

EXPOSE 8000
