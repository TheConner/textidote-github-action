FROM registry.access.redhat.com/ubi9/ubi AS build

# Install java build tools
# Need jmods and binutils
RUN yum install --disableplugin=subscription-manager -y java-17-openjdk-devel \
  java-17-openjdk-jmods \
  binutils \
  git

# Grab latest textidote release
#RUN curl -s https://api.github.com/repos/sylvainhalle/textidote/releases/latest \
#  | grep "browser_download_url.*jar" \
#  | cut -d : -f 2,3 \
#  | tr -d '"' \
#  | xargs -n 1 curl -O -L

# For testing github actions output, build the fork of the project:
ADD https://dlcdn.apache.org/ant/binaries/apache-ant-1.10.12-bin.tar.gz /root/ant.tar.gz
RUN git clone -b github-workflow-annotations https://github.com/TheConner/textidote.git
WORKDIR textidote
ENV JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF8
RUN tar -xzvf /root/ant.tar.gz && \
    mv apache-ant* /ant && \
    /ant/bin/ant download-deps && \
    /ant/bin/ant
# end testing build stuff


# Build minimal java
RUN $JAVA_HOME/bin/jlink \
  --add-modules java.base,java.xml,java.naming \
  --strip-debug \
  --no-man-pages \
  --no-header-files \
  --compress=2 \
  --output /javaruntime

FROM registry.access.redhat.com/ubi9-micro:latest

COPY --from=build /textidote/textidote-0.9.jar /textidote.jar
COPY --from=build /javaruntime /jre

WORKDIR /github/workspace
ENTRYPOINT ["/jre/bin/java", "-jar", "/textidote.jar"]

# Size comparison: 
# openjdk:8
#   podman inspect -f "{{ .Size }}" textidote-ci | numfmt --to=si
#   763M
# RHEL UBI + custom JRE
# podman inspect -f "{{ .Size }}" textidote-ci | numfmt --to=si
#   306M