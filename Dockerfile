# FROM zricethezav/gitleaks:latest
FROM ghcr.io/gitleaks/gitleaks:latest@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f

LABEL "com.github.actions.name"="Gitleaks Scanner"
LABEL "com.github.actions.description"="Runs Gitleaks in your CI/CD workflow"
LABEL "com.github.actions.icon"="shield"
LABEL "com.github.actions.color"="purple"
LABEL "repository"="https://github.com/DariuszPorowski/github-action-gitleaks"

COPY .gitleaks/* /.gitleaks/
COPY entrypoint.sh /entrypoint.sh
USER root
ENTRYPOINT ["/entrypoint.sh"]
