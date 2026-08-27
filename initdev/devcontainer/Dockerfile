FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install apps via script
COPY ./app_installs.bash /root/app_installs.bash
RUN bash /root/app_installs.bash

USER vscode

# Create .config sub-directories in the home dir
RUN mkdir -p \
  "/home/vscode/.config/Cursor" \
  "/home/vscode/.config/cursor" \
  "/home/vscode/.config/nushell" \
  "/home/vscode/.config/powershell"

# Copy a basic nushell profile and prompt that emulates the devcontainer default bash prompt
COPY ./*.nu /home/vscode/.config/nushell/

# Install Cursor agent cli
RUN curl -LfsS "https://cursor.com/install" | bash

# Enable vi mode in bash by default
RUN touch ~/.bashrc && printf '%s\n' 'set -o vi' >> ~/.bashrc


ENV PATH="/home/vscode/.local/bin:${PATH}"
