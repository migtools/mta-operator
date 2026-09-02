FROM registry.redhat.io/openshift4/ose-ansible-rhel9-operator:v4.20
USER root
COPY tools/upgrades/migrate-pathfinder-assessments.py /usr/local/bin/migrate-pathfinder-assessments.py
COPY tools/upgrades/jwt.sh /usr/local/bin/jwt.sh

ARG COMMUNITY_GENERAL="community-general-4.8.11.tar.gz"
ARG COMMUNITY_POSTGRESQL="community-postgresql-3.10.2.tar.gz"
ARG JMESPATH_WHL="jmespath-1.1.0-py3-none-any.whl"
COPY hack/build/${COMMUNITY_GENERAL} ${HOME}/${COMMUNITY_GENERAL}
COPY hack/build/${COMMUNITY_POSTGRESQL} ${HOME}/${COMMUNITY_POSTGRESQL}
COPY hack/build/${JMESPATH_WHL} ${HOME}/${JMESPATH_WHL}
RUN ansible-galaxy collection install ${HOME}/${COMMUNITY_GENERAL} ${HOME}/${COMMUNITY_POSTGRESQL} && rm ${HOME}/${COMMUNITY_GENERAL} ${HOME}/${COMMUNITY_POSTGRESQL}
RUN dnf module enable -y postgresql:15
RUN dnf install -y postgresql python3-psycopg2 && dnf clean all
RUN python3.12 -m pip install --no-index --no-deps ${HOME}/${JMESPATH_WHL} && rm ${HOME}/${JMESPATH_WHL}
USER 1001
COPY --chown=1001:0 watches.yaml ${HOME}/watches.yaml
COPY --chown=1001:0 roles ${HOME}/roles
COPY --chown=1001:0 playbooks ${HOME}/playbooks
COPY --chown=1001:0 LICENSE /licenses/

# Hack java bundle property location downstream (can't use snapshoted artifacts)
RUN sed -r -i 's/java-analyzer-bundle.core-1.0.0-SNAPSHOT.jar/java-analyzer-bundle.core.jar/' ${HOME}/roles/tackle/templates/customresource-extension.yml.j2

# Switch image_pull_policy downstream to IfNotPresent (We pull images by SHA digest not floating tags)
RUN sed -i 's/^image_pull_policy: "Always"$/image_pull_policy: "IfNotPresent"/' ${HOME}/roles/tackle/defaults/main.yml

LABEL \
        description="Migration Toolkit for Applications - Operator" \
        io.k8s.description="Migration Toolkit for Applications - Operator" \
        io.k8s.display-name="MTA - Operator" \
        io.openshift.maintainer.project="MTA" \
        io.openshift.tags="migration,modernization,mta,tackle,konveyor" \
        summary="Migration Toolkit for Applications - Operator"
