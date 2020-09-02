########################
# Build Stage
########################
FROM debian:buster-slim as builder

## Configuration
########################
ARG OPENLDAP_BUILD_VERSION=OPENLDAP_REL_ENG_2_4_50
ARG OPENLDAP_BCRYPT_VERSION=master
ARG BCRYPT_DEFAULT_WORKFACTOR=8
ARG MAKE_BUILD_JOBS=8

## Prepare
########################
# Install build tools
RUN apt-get update && apt-get -y install apt-utils git man-db libdb5.3-dev libssl-dev autoconf build-essential libtool libldap2-dev
# Create output directory
RUN mkdir /libtocopy
# Build openldap
RUN git clone --branch ${OPENLDAP_BUILD_VERSION} --depth 1 https://git.openldap.org/openldap/openldap.git openldap
WORKDIR /openldap
RUN ./configure --enable-modules
RUN make depend
RUN make --jobs ${MAKE_BUILD_JOBS}

## Build BCRYPT module
########################
WORKDIR /openldap/contrib/slapd-modules/passwd
RUN git clone --branch ${OPENLDAP_BCRYPT_VERSION} --depth 1 https://github.com/wclarie/openldap-bcrypt.git bcrypt
WORKDIR /openldap/contrib/slapd-modules/passwd/bcrypt
RUN sed -i "s/#define BCRYPT_DEFAULT_WORKFACTOR [[:digit:]]\+/#define BCRYPT_DEFAULT_WORKFACTOR $BCRYPT_DEFAULT_WORKFACTOR/g" pw-bcrypt.c
RUN make --jobs ${MAKE_BUILD_JOBS}
RUN cp pw-bcrypt.la .libs/pw-bcrypt.so .libs/pw-bcrypt.so.0 .libs/pw-bcrypt.so.0.0.0 /libtocopy
WORKDIR /openldap

########################
# RUN Stage
########################
FROM osixia/openldap:1.4.0
# Copy modules from build to productive image
COPY --from=builder /libtocopy /usr/lib/ldap/
ADD bootstrap/ldif/custom/*.ldif /container/service/slapd/assets/config/bootstrap/ldif/custom/
