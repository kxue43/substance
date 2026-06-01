FROM registry.fedoraproject.org/fedora:43

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN dnf install -y \
    hostname \
    bash-completion \
    git \
    curl \
    rlwrap \
    jq \
    fzf \
    bat \
    tree \
    neovim \
    pre-commit \
    golang \
    nodejs \
    awscli2 \
    gh \
    shellcheck \
    && dnf clean all

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

RUN go install mvdan.cc/sh/v3/cmd/shfmt@latest

# Create the user and give them passwordless sudo access
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
