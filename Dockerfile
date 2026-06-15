FROM nixos/nix:latest

# Enable flakes and disable sandbox (required inside containers)
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf \
    && echo "sandbox = false" >> /etc/nix/nix.conf

# Pre-install devShell tools so runtime startup is fast.
# The project flake.nix is mounted at runtime — this snapshot just
# pre-warms the nix store with the expected package set.
RUN nix profile install --priority 4 \
    nixpkgs#bash \
    nixpkgs#bats \
    nixpkgs#git \
    nixpkgs#coreutils \
    nixpkgs#findutils \
    nixpkgs#gnused \
    nixpkgs#gnugrep

WORKDIR /workspace
CMD ["/bin/bash"]
